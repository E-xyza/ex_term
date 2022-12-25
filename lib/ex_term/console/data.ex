defmodule ExTerm.Console.Data do
  @moduledoc false
  alias ExTerm.Style
  alias ExTerm.Console.Cell
  alias ExTerm.Console.Row

  @defaults [rows: 40, columns: 80, style: Style.new(), cursor: {1, 1}]
  @type coordinate :: {non_neg_integer, non_neg_integer}
  @type rows :: [[{coordinate, Cell.t()}]]

  @spec new(keyword) :: :ets.table()
  def new(opts \\ []) do
    opts = Keyword.merge(@defaults, opts)

    rows = Keyword.fetch!(opts, :rows)
    columns = Keyword.fetch!(opts, :columns)

    # NB: private for now.  This may change in the future.
    #
    # :ordered_set incurs a penalty for single item lookups but since a lot of
    # the accesses that we will be doing are on a range, it makes sense to use
    # ordered_set for this purpose.

    table = :ets.new(__MODULE__, [:private, :ordered_set])

    initial_entries =
      for row <- 1..rows, column <- 1..columns do
        {{row, column}, %Cell{}}
      end

    # we're going to store metadata in the ets table, so that when we're
    # sharing information, it commutes over the other processes that are
    # accessing the data.

    :ets.insert(table, opts ++ initial_entries)

    table
  end

  @options_query [{{:"$1", :"$2"}, [{:is_atom, :"$1"}], [{{:"$1", :"$2"}}]}]

  @doc """
  fetches all metadata from the ets table
  """
  def metadata(table) do
    :ets.select(table, @options_query)
  end

  @doc """
  fetches a single item of metadata from the ets table, or multiple
  items, ordered
  """
  def metadata(table, key_or_keys) do
    result = :ets.select(table, metadata_key_query(key_or_keys))

    case key_or_keys do
      key when is_atom(key) -> List.first(result)
      keys when is_list(keys) -> result
    end
  end

  @doc """
  sets metadata on the provided key(s) to the provided value, which must be a kwl
  """
  def put_metadata(table, kvs) do
    :ets.insert(table, kvs)
  end

  @key :"$1"
  @value :"$2"

  defp metadata_key_query(keys) when is_list(keys) do
    filter =
      keys
      |> Enum.map(&{:"=:=", @key, &1})
      |> Enum.reduce(&{:or, &1, &2})

    [{{@key, @value}, [filter], [@value]}]
  end

  defp metadata_key_query(key) when is_atom(key),
    do: [{{@key, @value}, [{:"=:=", @key, key}], [@value]}]

  @spec console(:ets.table()) :: {cursor :: coordinate, rows}
  @doc """
  fetches the console region of the table.

  Not wrapped in a transaction.
  """
  # it's possible that not wrapping this in a transaction could cause problems
  # so this code might need to be revisited.
  def console(table) do
    # note that the keys here are in erlang term order.
    [columns, cursor, rows] = metadata(table, [:columns, :cursor, :rows])
    last_row = last_row(table)
    first_row = last_row - rows + 1
    {cursor, get_rows(table, first_row..last_row, columns)}
  end

  # generic row fetching
  def get_rows(table, row_or_range, columns) do
    case row_or_range do
      first_row..last_row ->
        table
        |> :ets.select(console_query(first_row, last_row, columns))
        |> Enum.chunk_by(&Row.number/1)

      row when is_integer(row) ->
        [:ets.select(table, console_query(row, row, columns))]
    end
  end

  @row :"$1"
  @column :"$2"
  defp console_query(first_row, last_row, columns) do
    [
      {{{@row, @column}, :_},
       [{:>=, @row, first_row}, {:"=<", @row, last_row}, {:"=<", @column, columns}], [:"$_"]}
    ]
  end

  @doc """
  puts a character, in the current style at the expected place.
  """
  def put_char(table, char) do
    [columns, cursor, style] = metadata(table, [:columns, :cursor, :style])

    :ets.insert(table, [
      {cursor, %Cell{style: style, char: char}} | cursor_advance(cursor, columns)
    ])

    table
  end

  @doc """
  performs a crlf operation on the cursor.
  """
  def cursor_crlf(table) do
    [columns, {row, _}] = metadata(table, [:columns, :cursor])

    last_row = last_row(table)
    new_row = row + 1
    :ets.insert(table, {:cursor, {new_row, 1}})

    if new_row > last_row do
      :ets.insert(table, Enum.map(1..columns, &{{new_row, &1}, Cell.new()}))
    end

    table
  end

  @doc """
  returns the highest index of a row that exists in the buffer.
  """
  def last_row(table) do
    # note that all metadata occurs before tuples because atoms have
    # lower erlang term ordering than tuples.
    table
    |> :ets.last()
    |> elem(0)
  end

  @doc """
  calculates `buffer shift`, which is how many lines you need to move from
  a fixed console section to the buffer.
  """
  def buffer_shift(table, top_console_row) do
    [columns, rows] = metadata(table, [:columns, :rows])
    bottom_buffer_row = last_row(table) - rows

    if bottom_buffer_row >= top_console_row do
      {get_rows(table, top_console_row..bottom_buffer_row, columns), bottom_buffer_row + 1}
    else
      {[], top_console_row}
    end
  end

  @doc """
  sends a string to the console at a position, resetting the cursor to a
  place within the string or at its end.

  If it's a binary, it must be unicode-encoded, with no ANSI control
  characters.  Style is set by the current style of the

  If it's a list, it must be a list of either single characters or
  style structs.  If it's a style struct, then it replaces the current
  style of the console with the new style.
  """
  def paint_chars(_table, nil, _content, _cursor_offset), do: :ok

  def paint_chars(table, location, content, cursor_offset) do
    [columns, style] = metadata(table, [:columns, :style])
    do_paint_chars(table, location, content, cursor_offset, columns, style)
  end

  defp do_paint_chars(table, {row, column}, content, cursor_offset, columns, style)
       when is_binary(content) do

    case String.next_grapheme(content) do
      {grapheme, rest} ->
        next_location = adjust_cursor({row, column + 1}, columns)

        table
        |> put_char_with({row, column}, grapheme, style)
        |> maybe_paint_row(next_location, columns)
        |> do_paint_chars(
          next_location,
          rest,
          decrement_or_tuple(cursor_offset, {row, column}),
          columns,
          style
        )

      nil when cursor_offset == 1 ->
        put_metadata(table, cursor_advance({row, column}, columns))

      nil when cursor_offset == 0 ->
        put_metadata(table, cursor: {row, column})

      nil when is_tuple(cursor_offset) ->
        put_metadata(table, cursor: cursor_offset)
    end
  end

  defp do_paint_chars(table, _, [], cursor_tuple, _, _) do
    put_metadata(table, cursor: cursor_tuple)
  end

  defp do_paint_chars(table, {row, column}, [grapheme | rest], cursor_offset, columns, style)
       when is_binary(grapheme) do
    next_location = adjust_cursor({row, column + 1}, columns)

    table
    |> put_char_with({row, column}, grapheme, style)
    |> maybe_paint_row(next_location, columns)
    |> do_paint_chars(
      next_location,
      rest,
      decrement_or_tuple(cursor_offset, {row, column}),
      columns,
      style
    )
  end

  defp do_paint_chars(table, location, [style = %Style{} | rest], cursor_offset, columns, _) do
    do_paint_chars(table, location, rest, cursor_offset, columns, style)
  end

  defp decrement_or_tuple(0, tuple), do: tuple
  defp decrement_or_tuple(count, _) when is_integer(count), do: count - 1
  defp decrement_or_tuple(tuple, _) when is_tuple(tuple), do: tuple

  #######################################################################
  ## TOOLS

  def cursor_advance({row, column}, columns) do
    [{:cursor, adjust_cursor({row, column + 1}, columns)}]
  end

  defp adjust_cursor({row, column}, columns) when column > columns, do: {row + 1, 1}

  defp adjust_cursor(cursor, _), do: cursor

  defp put_char_with(table, location, grapheme, style) do
    :ets.insert(table, {location, %Cell{char: grapheme, style: style}})
    table
  end

  defp maybe_paint_row(table, {row, _}, columns) do
    if last_row(table) < row do
      :ets.insert(
        table,
        for column <- 1..columns do
          {{row, column}, %Cell{}}
        end
      )
    end

    table
  end

  def dump(table) do
    table
    |> :ets.select([{{{:_, :_}, :_}, [], [:"$_"]}])
    |> Enum.chunk_by(&Row.number/1)
    |> Enum.each(fn row = [{{index, _}, _} | _] ->
      label = String.pad_leading("#{index}:", 3)
      IO.puts([label | Enum.map(row, fn {{_, _}, cell} -> List.wrap(cell.char) end)])
    end)
  end
end
