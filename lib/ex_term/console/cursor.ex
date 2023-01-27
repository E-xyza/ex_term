defmodule ExTerm.Console.Cursor do
  @doc false
  alias ExTerm.Console
  alias ExTerm.Console.Cell
  alias ExTerm.Console.Update

  use MatchSpec

  @home IO.ANSI.home()
  @clear IO.ANSI.clear()
  @clear_line IO.ANSI.clear_line()

  @spec from_ansi(String.t(), Console.t(), Console.location(), to_flush :: Update.cell_changes()) ::
          :not_cursor | {:update, Console.location(), Update.t(), String.t()}

  def from_ansi(@home <> rest, console, {cursor_row, _}, changes) do
    Console.insert(console, changes)
    {rows, cols} = Console.layout(console)

    updates =
      Enum.flat_map((cursor_row + 1)..(cursor_row + rows), fn row ->
        case Console.columns(console, row) do
          0 ->
            # doesn't exist.  Fill it out to the layout length, pad with sentinel.
            [{{row, cols + 1}, Cell.sentinel()} | Enum.map(1..cols, &{{row, &1}, %Cell{}})]

          length ->
            Enum.map(1..length, &{{row, &1}, %Cell{}})
        end
      end)

    Console.insert(console, updates)
    new_cursor = {cursor_row + 1, 1}
    {:update, new_cursor, {new_cursor, :end}, rest}
  end

  def from_ansi(@clear <> rest, console, cursor, changes) do
    Console.insert(console, changes)
    # this clears only the "current console".  Do this by looking up the console layout and
    # last row and fill out everything after that.  Doesn't add in extra rows.
    {rows, _} = Console.layout(console)
    {last_row, _} = Console.last_cell(console)
    clear_start = {last_row - rows + 1, 1}
    to_clear = Console.select(console, select_clear_from(clear_start))
    Console.insert(console, to_clear)

    {:update, cursor, {clear_start, :end}, rest}
  end

  def from_ansi(@clear_line <> rest, console, cursor = {row, _}, changes) do
    Console.insert(console, changes)
    to_clear = Console.select(console, select_clear_row(row))
    Console.insert(console, to_clear)
    {:update, cursor, {{row, 1}, {row, :end}}, rest}
  end

  def from_ansi(_, _, _, _), do: :not_cursor

  defmatchspecp select_clear_from(from) do
    {location, cell} when location >= from and cell.char !== "\n" -> {location, %Cell{}}
  end

  defmatchspecp select_clear_row(row) do
    {{^row, column}, cell} when cell.char !== "\n" -> {{row, column}, %Cell{}}
  end
end
