defmodule ExTerm.Console.StringTracker do
  @moduledoc false

  # special module to do simple compound string operations on the console.
  # this includes:
  #
  # - put_string_rows
  # - insert_string_rows

  alias ExTerm.Console
  alias ExTerm.Console.Cell
  require Console

  @enforce_keys [:console, :style, :cursor, :layout, :first_updated, :last_updated, :last_cell]
  defstruct @enforce_keys ++ [updates: []]

  @type t :: %__MODULE__{
          console: Console.t(),
          style: Style.t(),
          cursor: Console.location(),
          layout: Console.location(),
          first_updated: Console.location(),
          last_updated: Console.location(),
          last_cell: Console.location()
        }

  def new(console) do
    [cursor: cursor, layout: layout, style: style] = Console.get_metadata(console, [:cursor, :layout, :style])
    last_cell = Console.last_cell(console)

    %__MODULE__{
      cursor: cursor,
      style: style,
      console: console,
      layout: layout,
      first_updated: cursor,
      last_updated: cursor,
      last_cell: last_cell
    }
  end

  @spec put_string_rows(StringTracker.t(), String.t()) :: StringTracker.t()
  def put_string_rows(tracker = %{cursor: {row, _}}, string) do
    columns = Console.columns(tracker.console, row)

    case put_string_row(tracker, columns, string) do
      # exhausted the row without finishing the string
      {updated_tracker, leftover} ->
        put_string_rows(%{updated_tracker | cursor: {row + 1, 1}}, leftover)

      done ->
        done
    end
  end

  def put_string_row(
         tracker = %{cursor: {row, column}, console: console, last_cell: {last_row, last_cell_column}},
         columns,
         string
       )
       when column === columns + 1 do
    if row === last_row do
      # if we're at the end of the tracker, be sure to add a new row, first
      new_row = row + 1
      {_, columns} = tracker.layout
      Console.insert(console, Console.make_blank_row(new_row, columns))
      {%{tracker | last_cell: {new_row, last_cell_column}}, string}
    else
      {tracker, string}
    end
  end

  def put_string_row(tracker , columns, "\t" <> string) do
    {hard_tab(tracker, columns), string}
  end

  def put_string_row(tracker, _columns, "\r\n" <> string) do
    {hard_return(tracker), string}
  end

  def put_string_row(tracker, _columns, "\r" <> string) do
    {hard_return(tracker), string}
  end

  def put_string_row(tracker, _columns, "\n" <> string) do
    {hard_return(tracker), string}
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

  @spec send_update(t, keyword) :: t
  def send_update(tracker = %{cursor: cursor, console: console}, opts \\ []) do
    console
    |> Console.put_metadata(:cursor, cursor)
    |> Console.insert(tracker.updates)

    last_updated = if Keyword.get(opts, :with_cursor), do: cursor, else: tracker.last_updated

    case Console.get_metadata(tracker.console, :handle_update) do
      fun when is_function(fun, 1) ->
        fun.(
          Console.update_msg(
            from: tracker.first_updated,
            to: last_updated,
            cursor: cursor,
            last_cell: tracker.last_cell
          )
        )

      nil ->
        :ok

      other ->
        raise "invalid update handler, expected arity 1 fun, got #{inspect(other)}"
    end

    %{tracker | updates: []}
  end

  # special events

  defp hard_return(tracker = %{cursor: {row, _column}}) do
    new_cursor = {row + 1, 1}
    tracker
    |> Map.put(:cursor, new_cursor)
    |> send_update
    |> Map.merge(%{first_updated: new_cursor, last_updated: new_cursor})
  end

  defp hard_tab(tracker = %{cursor: {row, column}}, columns) do
    new_cursor = case (div(column, 10) + 1) * 10 do
      new_column when new_column > columns ->
        {row + 1, 1}
      new_column -> {row, new_column}
    end

    tracker
    |> Map.put(:cursor, new_cursor)
    |> send_update
    |> Map.merge(%{first_updated: new_cursor, last_updated: new_cursor})
  end
end
