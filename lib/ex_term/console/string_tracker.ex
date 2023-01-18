defmodule ExTerm.Console.StringTracker do
  @moduledoc false

  # special private module to do compound string operations on the console.
  # This module tracks a set of changes that are directed by an input string
  # and virtualizes them into a list of updates, which are of type
  # Console.cellinfo/1.  These updates should be flushed
  #
  # Private exported interface:
  #
  # - put_string_rows
  # - insert_string_rows
  # - flush_updates
  #
  # Testable but private:
  #
  # - blit_string_row

  use MatchSpec

  alias ExTerm.Console
  alias ExTerm.Console.Cell
  alias ExTerm.Console.Update

  require Console

  @enforce_keys [
    :insertion,
    :console,
    :style,
    :cursor,
    :old_cursor,
    :layout,
    :last_cell
  ]
  defstruct @enforce_keys ++ [updates: []]

  @type t :: %__MODULE__{
          insertion: nil | pos_integer(),
          console: Console.t(),
          style: Style.t(),
          cursor: Console.location(),
          old_cursor: Console.location(),
          layout: Console.location(),
          first_updated: Console.location(),
          last_updated: Console.location(),
          last_cell: Console.location()
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
      first_updated: new_cursor,
      last_updated: new_cursor,
      last_cell: last_cell
    }
  end

  @spec put_string_rows(t(), String.t()) :: t()
  def put_string_rows(tracker = %{insertion: nil}, string) do
    # NB: don't cache the number of rows.  Row length should be fixed once set.
    columns = columns_for_row(tracker)

    case put_string_row(tracker, columns, string) do
      # exhausted the row without finishing the string
      {updated_tracker, leftover} ->
        put_string_rows(updated_tracker, leftover)

      done ->
        done
        |> pad_last_row(columns)
        |> update_insert()
    end
  end

  @spec insert_string_rows(t(), String.t()) :: t()
  def insert_string_rows(tracker = %{insertion: row}, string) when is_integer(row) do
    # NB: don't cache the number of columns.  Row length should be fixed based
    # on the existing capacity of the columns so far.

    columns = columns_for_row(tracker)

    case put_string_row(tracker, columns, string) do
      {new_tracker, leftover} ->
        insert_string_rows(new_tracker, leftover)

      done = %{updates: [{{last_row, _}, _} | _]} ->
        # figure out how many rows we need to move.  This is determined by the number
        # of rows in the update.  Let's assume that it is the row of the first item.

        move_distance = last_row - row + 1

        done
        |> pad_last_row(columns)
        |> update_cursor(tracker.old_cursor, row, move_distance)
        |> update_insert()
    end
  end

  defp columns_for_row(tracker = %{console: console, cursor: {row, _}, layout: layout}) do
    case Console.columns(console, row) do
      # this row doesn't exist yet.
      0 -> elem(layout, 1)
      columns -> columns
    end
  end

  def put_string_row(tracker = %{cursor: cursor = {row, column}}, columns, string)
      when column > columns do
    # make sure the update contains a sentinel at the cursor location.
    {%{tracker | cursor: {row + 1, 1}, updates: [{cursor, Cell.sentinel()} | tracker.updates]},
     string}
  end

  def put_string_row(tracker, columns, "\t" <> rest) do
    {hard_tab(tracker, columns), rest}
  end

  def put_string_row(tracker, _columns, "\r\n" <> rest) do
    {hard_return(tracker), rest}
  end

  def put_string_row(tracker, _columns, "\r" <> rest) do
    {hard_return(tracker), rest}
  end

  def put_string_row(tracker, _columns, "\n" <> rest) do
    {hard_return(tracker), rest}
  end

  def put_string_row(tracker = %{cursor: cursor}, columns, string = "\e" <> _) do
    case ExTerm.ANSI.parse(string, {tracker.style, cursor}) do
      # no cursor change.
      {rest, {style, ^cursor}} ->
        put_string_row(%{tracker | style: style}, columns, rest)
    end
  end

  def put_string_row(tracker = %{cursor: cursor = {row, column}}, columns, string) do
    case String.next_grapheme(string) do
      nil ->
        tracker

      {grapheme, rest} ->
        updates = [{cursor, %Cell{char: grapheme, style: tracker.style}} | tracker.updates]

        put_string_row(
          %{tracker | cursor: {row, column + 1}, last_updated: cursor, updates: updates},
          columns,
          rest
        )
    end
  end

  defp pad_last_row(tracker = %{cursor: {_, cursor_column}}, columns) do
    {row, keys} =
      Enum.reduce(tracker.updates, {0, MapSet.new()}, fn
        {location = {this_row, _}, _}, {highest_row, keys} ->
          new_highest_row = if this_row > highest_row, do: this_row, else: highest_row
          {new_highest_row, MapSet.put(keys, location)}
      end)

    new_updates =
      for column <- cursor_column..columns, {row, column} not in keys, reduce: tracker.updates do
        updates -> [{{row, column}, %Cell{}} | updates]
      end

    # fill out the row.
    %{tracker | updates: prepend_sentinel(new_updates, {row, columns + 1})}
  end

  defp update_cursor(tracker, old_cursor, insert_row, move_distance) do
    new_cursor =
      case old_cursor do
        {row, _} when row < insert_row ->
          old_cursor

        {row, column} ->
          {row + move_distance, column}
      end

      |> dbg(limit: 25)
    %{tracker | cursor: new_cursor}
  end

  defp update_insert(tracker = %{updates: [{location = {row, column}, _} | _]}) do
    %{tracker | last_updated: location, last_cell: {row, column - 1}}
  end

  # special events that are common

  defguardp is_inserting(tracker) when tracker.insertion !== nil

  # if we're beyond the last row of the console (or doing an insertion), go ahead and
  # fill in the rest of the row.  In both cases, we can defer sending the update because
  # we know that updates from here on are going to be continuous.
  defp hard_return(
         tracker = %{cursor: {row, column}, last_cell: {last_row, _}, layout: {_, columns}}
       )
       when row > last_row or is_inserting(tracker) do
    updates =
      column..columns
      |> Enum.reduce(tracker.updates, &prepend_blank(&2, {row, &1}))
      |> prepend_sentinel({row, columns + 1})

    %{tracker | cursor: {row + 1, 1}, updates: updates, last_cell: {row + 1, columns}}
  end

  defp hard_return(tracker = %{cursor: {row, _column}}) do
    new_cursor = {row + 1, 1}

    tracker
    |> Map.put(:cursor, new_cursor)
    |> Map.merge(%{first_updated: new_cursor, last_updated: new_cursor})
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
    {new_cursor, updates, new_last_cell} =
      case tab_destination(column) do
        new_column when new_column >= columns ->
          updates =
            column..columns
            |> Enum.reduce(tracker.updates, &prepend_blank(&2, {row, &1}))
            |> prepend_sentinel({row, columns + 1})

          {{row + 1, 1}, updates, {last_row, columns}}

        new_column ->
          updates =
            Enum.reduce(column..(new_column - 1), tracker.updates, &prepend_blank(&2, {row, &1}))

          {{row, new_column}, updates, last_cell}
      end

    %{tracker | cursor: new_cursor, updates: updates, last_cell: new_last_cell}
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
  defp prepend_blank(updates, location), do: [{location, %Cell{}} | updates]
  defp prepend_sentinel(updates, location), do: [{location, Cell.sentinel()} | updates]

  defp tab_destination(column) do
    (div(column, 10) + 1) * 10
  end
end
