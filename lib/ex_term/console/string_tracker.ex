defmodule ExTerm.Console.StringTracker do
  @moduledoc false

  # special private module that encapsulates and stores compound string
  # operations on the console.  This module allows code sharing between the
  # put_string and insert_string functionality.  It tracks a set of changes that
  # are directed by an input string (e.g. unicode characters put at cursor
  # location, style changes, etc.) and virtualizes them into a list of
  # cellinfo changes to be flushed to the console later.
  #
  # Private exported interface:
  #
  # - new
  # - put_string_rows
  # - insert_string_rows
  # - flush_updates
  #
  # Testable but private:
  #
  # - _blit_string_row

  use MatchSpec

  alias ExTerm.Console
  alias ExTerm.Console.Cell
  alias ExTerm.Console.Update

  require Console

  @enforce_keys [
    :console,
    :insertion,
    :style,
    :cursor,
    :old_cursor,
    :layout,
    :last_cell
  ]

  defstruct @enforce_keys ++ [update: %Update{}, cells: []]

  @type t :: %__MODULE__{
          insertion: nil | pos_integer(),
          console: Console.t(),
          style: Style.t(),
          cursor: Console.location(),
          old_cursor: Console.location(),
          layout: Console.location(),
          last_cell: Console.location(),
          update: Update.t(),
          cells: [Console.cellinfo()]
        }

  @spec new(Console.t(), nil | pos_integer()) :: t
  def new(console, insertion \\ nil) do
    [cursor: old_cursor, layout: layout, style: style] =
      Console.get_metadata(console, [:cursor, :layout, :style])

    new_cursor = if insertion, do: {insertion, 1}, else: old_cursor
    last_cell = Console.last_cell(console)

    %__MODULE__{
      insertion: insertion,
      cursor: new_cursor,
      old_cursor: old_cursor,
      style: style,
      console: console,
      layout: layout,
      last_cell: last_cell
    }
  end

  @spec put_string_rows(t(), String.t()) :: t()
  def put_string_rows(tracker = %{insertion: nil}, string) do
    # NB: don't cache the number of rows.  Row length should be fixed once set.
    columns = columns_for_row(tracker)

    case _blit_string_row(tracker, columns, string) do
      # exhausted the row without finishing the string
      {updated_tracker, leftover} ->
        put_string_rows(updated_tracker, leftover)

      done -> done
    end
  end

  @spec insert_string_rows(t(), String.t()) :: t()
  def insert_string_rows(tracker = %{insertion: row}, string) when is_integer(row) do
    # NB: don't cache the number of columns.  Row length should be fixed based
    # on the existing capacity of the columns so far.

    columns = columns_for_row(tracker)

    case _blit_string_row(tracker, columns, string) do
      {new_tracker, leftover} ->
        insert_string_rows(new_tracker, leftover)

      _done ->
        raise "aaaaaagh"
    end
  end

  defp columns_for_row(%{console: console, cursor: {row, _}, layout: layout}) do
    case Console.columns(console, row) do
      # this row doesn't exist yet.
      0 -> elem(layout, 1)
      columns -> columns
    end
  end

  # if we're trying to insert content on a row that doesn't exist yet, go
  # ahead and put that row at the end of the console, but don't put this in
  # the list of cells to update (this minimizes double-tap risk by ensuring
  # that the act of creating the row is separated from the act of flushing
  # data and we don't have to worry about the blank line overwriting later
  # insertions with the same coordinate).
  def _blit_string_row(tracker = %{cursor: {row, _column}, last_cell: {last_row, _}, layout: {_, layout_columns}}, _, string)
    when row === last_row + 1 do
    Console.insert(tracker.console, Console.make_blank_row(row, layout_columns))

    tracker
    |> Map.replace!(:last_cell, {row, layout_columns})
    |> Map.update!(:update, &Update.merge_into(&1, {{row, 1}, :end}))
    |> _blit_string_row(layout_columns, string)
  end

  def _blit_string_row(tracker = %{cursor: cursor = {row, column}}, columns, string)
      when column > columns do
    # make sure that the update reflects that this is the end line
    new_update = Update.merge_into(tracker.update, {cursor, {row, :end}})
    {%{tracker | cursor: {row + 1, 1}, update: new_update}, string}
  end

  def _blit_string_row(tracker, columns, "\t" <> rest) do
    {hard_tab(tracker, columns), rest}
  end

  def _blit_string_row(tracker, _columns, "\r\n" <> rest) do
    {hard_return(tracker), rest}
  end

  def _blit_string_row(tracker, _columns, "\r" <> rest) do
    {hard_return(tracker), rest}
  end

  def _blit_string_row(tracker, _columns, "\n" <> rest) do
    {hard_return(tracker), rest}
  end

  def _blit_string_row(tracker = %{cursor: cursor}, columns, string = "\e" <> _) do
    case ExTerm.ANSI.parse(string, {tracker.style, cursor}) do
      # no cursor change.
      {rest, {style, ^cursor}} ->
        _blit_string_row(%{tracker | style: style}, columns, rest)
    end
  end

  def _blit_string_row(tracker = %{cursor: cursor = {row, column}}, columns, string) do
    case String.next_grapheme(string) do
      nil ->
        tracker

      {grapheme, rest} ->
        new_cells = [{cursor, %Cell{char: grapheme, style: tracker.style}} | tracker.cells]
        new_update = Update.merge_into(tracker.update, cursor)

        tracker
        |> Map.merge(%{cursor: {row, column + 1}, update: new_update, cells: new_cells})
        |> _blit_string_row(columns, rest)
    end
  end

  defp update_cursor(tracker, old_cursor, insert_row, move_distance) do
    new_cursor =
      case old_cursor do
        {row, _} when row < insert_row ->
          old_cursor

        {row, column} ->
          {row + move_distance, column}
      end

    %{tracker | cursor: new_cursor}
  end

  defp update_insert(tracker = %{cells: [{location = {row, column}, _} | _]}) do
    %{tracker | last_updated: location, last_cell: {row, column - 1}}
  end

  # special events that are common

  defguardp is_inserting(tracker) when tracker.insertion !== nil

  defp hard_return(tracker = %{cursor: {row, _}}) do
    %{tracker | cursor: {row + 1, 1}}
  end

  # if we're beyond the last row of the console (or doing an insertion), go
  # ahead and fill in to the position of where we are.
  defp hard_tab(
         tracker = %{
           cursor: {row, column},
           last_cell: last_cell = {last_row, _},
           layout: {_, columns}
         },
         _
       )
       when row > last_row or is_inserting(tracker) do
    {new_cursor, cells, new_last_cell} =
      case tab_destination(column) do
        new_column when new_column >= columns ->
          cells =
            column..columns
            |> Enum.reduce(tracker.cells, &prepend_blank(&2, {row, &1}))
            |> prepend_sentinel({row, columns + 1})

          {{row + 1, 1}, cells, {last_row, columns}}

        new_column ->
          cells =
            Enum.reduce(column..(new_column - 1), tracker.cells, &prepend_blank(&2, {row, &1}))

          {{row, new_column}, cells, last_cell}
      end

    %{tracker | cursor: new_cursor, cells: cells, last_cell: new_last_cell}
  end

  # since we are doing a disjoint update, we should send an update, early.
  defp hard_tab(tracker = %{cursor: {row, column}}, columns) do
    new_cursor =
      case tab_destination(column) do
        new_column when new_column > columns ->
          {row + 1, 1}

        new_column ->
          {row, new_column}
      end

    Map.merge(tracker, %{cursor: new_cursor, first_updated: new_cursor, last_updated: new_cursor})
  end

  # NOTE THE ORDER OF THE ARGUMENTS CAREFULLY
  defp prepend_blank(cells, location), do: [{location, %Cell{}} | cells]
  defp prepend_sentinel(cells, location), do: [{location, Cell.sentinel()} | cells]

  defp tab_destination(column) do
    (div(column, 10) + 1) * 10
  end
end
