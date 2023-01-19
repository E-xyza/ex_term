defmodule ExTerm.Console.StringTracker do
  @moduledoc false

  # special private module that encapsulates and stores compound string
  # operations on the console.  This module allows code sharing between the
  # put_string and insert_string functionality.  It tracks a set of changes that
  # are directed by an input string (e.g. unicode characters put at cursor
  # location, style changes, etc.) and virtualizes them into a list of
  # cellinfo changes to be flushed to the console later.
  #
  # if the StringTracker runs into a console control character, it will eject
  # from the normal change buffering mode and paint directly onto the console,
  # possibly updating the column width (but only if expansion is needed).
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
    :mode,
    :style,
    :cursor,
    :old_cursor,
    :layout,
    :last_cell
  ]

  defstruct @enforce_keys ++ [update: %Update{}, cells: []]

  @type mode ::
          :put | :paint | {:insert, from_row :: pos_integer(), total_rows :: non_neg_integer()}

  @type t :: %__MODULE__{
          console: Console.t(),
          mode: mode,
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

    {new_cursor, mode} =
      if insertion do
        {{insertion, 1}, {:insert, insertion, 1}}
      else
        {old_cursor, :put}
      end

    last_cell = Console.last_cell(console)

    %__MODULE__{
      mode: mode,
      cursor: new_cursor,
      old_cursor: old_cursor,
      style: style,
      console: console,
      layout: layout,
      last_cell: last_cell
    }
  end

  @spec put_string_rows(t(), String.t()) :: t()
  def put_string_rows(tracker = %{mode: :put, cursor: {row, _}}, string) do
    # NB: don't cache the number of rows.  Row length should be fixed based on
    # the existing capacity of the column, so we have to check each time.

    case _blit_string_row(tracker, Console.columns(tracker.console, row), string) do
      # exhausted the row without finishing the string
      {updated_tracker, leftover} ->
        put_string_rows(updated_tracker, leftover)

      done ->
        done
    end
  end

  @spec insert_string_rows(t(), String.t()) :: t()
  def insert_string_rows(tracker = %{mode: {:insert, _, _}, cursor: {row, _}}, string) do
    # NB: don't cache the number of columns.  Row length should be fixed based
    # on the existing capacity of the column, so we have to check each time.
    columns = Console.columns(tracker.console, row)

    case _blit_string_row(tracker, columns, string) do
      {new_tracker, leftover} ->
        insert_string_rows(new_tracker, leftover)

      done ->
        hard_return(done, columns)
    end
  end

  @spec flush_updates(t) :: t
  # flush updates handles three cases depending on what the state of the string tracker
  # is.  If it's in string mode, then it immediately
  def flush_updates(tracker = %{mode: {:insert, from_row, count}}) do
    count = count - 1
    # note that count has an extra because we do a hard return
    # at the end of an insert in all cases.
    update_cells =
      tracker.console
      |> Console._bump_rows(from_row, count)
      |> Enum.reverse(tracker.cells)

    new_cursor =
      case old_cursor = tracker.old_cursor do
        {row, _} when row < from_row ->
          old_cursor

        {row, column} ->
          {row + count, column}
      end

    tracker.console
    |> Console.insert(update_cells)
    |> Console.move_cursor(new_cursor)

    flush(tracker)
  end

  def flush_updates(tracker) do
    tracker.console
    |> Console.insert(tracker.cells)
    |> Console.move_cursor(tracker.cursor)

    flush(tracker)
  end

  defp flush(tracker) do
    Update.merge(tracker.update)
    %{tracker | cells: [], update: %Update{}, old_cursor: tracker.cursor}
  end

  def _blit_string_row(tracker = %{cursor: {row, column}}, columns, "")
      when column === columns + 1 do
    %{tracker | cursor: {row + 1, 1}}
  end

  def _blit_string_row(tracker, _, ""), do: tracker

  def _blit_string_row(tracker = %{mode: :put, cursor: {row, _}, layout: {_, columns}}, 0, string) do
    # since string MUST have a payload, obtain the layout columns and add that row in

    new_cells = Enum.reduce(1..columns, tracker.cells, &[{{row, &1}, %Cell{}} | &2])
    Console.insert(tracker.console, [{{row, columns + 1}, Cell.sentinel()} | new_cells])

    tracker
    |> Map.replace!(:update, Update.merge_into(tracker.update, {{row, 1}, {row, :end}}))
    |> _blit_string_row(columns, string)
  end

  def _blit_string_row(tracker = %{cursor: cursor = {row, column}}, columns, string)
      when column > columns do
    # make sure that the update reflects that this is the end line
    new_update =
      tracker
      |> Map.replace!(:update, Update.merge_into(tracker.update, {cursor, {row, :end}}))
      |> hard_return(columns)

    {new_update, string}
  end

  def _blit_string_row(tracker, columns, "\t" <> rest) do
    _blit_string_row(hard_tab(tracker), columns, rest)
  end

  def _blit_string_row(tracker, columns, "\r\n" <> rest) do
    {hard_return(tracker, columns), rest}
  end

  def _blit_string_row(tracker, columns, "\r" <> rest) do
    {hard_return(tracker, columns), rest}
  end

  def _blit_string_row(tracker, columns, "\n" <> rest) do
    {hard_return(tracker, columns), rest}
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
      {grapheme, rest} ->
        new_cells = [{cursor, %Cell{char: grapheme, style: tracker.style}} | tracker.cells]

        new_update = Update.merge_into(tracker.update, cursor)

        tracker
        |> Map.merge(%{cursor: {row, column + 1}, update: new_update, cells: new_cells})
        |> _blit_string_row(columns, rest)
    end
  end

  # special events that are common
  defp hard_tab(tracker = %{cursor: {row, column}}) do
    new_cursor = {row, tab_destination(column, 10)}
    %{tracker | cursor: new_cursor, update: %{tracker.update | cursor: new_cursor}}
  end

  defp hard_return(tracker = %{cursor: {row, column}, mode: {:insert, start, rows}}, columns) do
    new_mode = {:insert, start, rows + 1}

    new_cells = Enum.reduce(column..columns, tracker.cells, &[{{row, &1}, %Cell{}} | &2])

    %{tracker | cursor: {row + 1, 1}, mode: new_mode, cells: new_cells}
  end

  defp hard_return(tracker = %{cursor: {row, _}}, _) do
    %{tracker | cursor: {row + 1, 1}}
  end

  defp tab_destination(column, tab_length) do
    (div(column, tab_length) + 1) * tab_length
  end
end
