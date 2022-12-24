defmodule ExTerm.Console.Data do
  alias ExTerm.Style
  alias ExTerm.Console.Cell
  alias ExTerm.Console.Row

  @defaults [rows: 40, columns: 80, style: Style.new(), cursor: {1, 1}, prompt: false]
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

  @spec console(:ets.table()) :: {cursor :: coordinate, rows, prompting :: boolean}
  @doc """
  fetches the console region of the table.

  Not wrapped in a transaction.
  """
  # it's possible that not wrapping this in a transaction could cause problems
  # so this code might need to be revisited.
  def console(table) do
    # note that the keys here are in erlang term order.
    [columns, cursor, prompt, rows] = metadata(table, [:columns, :cursor, :prompt, :rows])
    last_row = last_row(table)
    first_row = last_row - rows + 1
    {cursor, get_rows(table, first_row..last_row, columns), !!prompt}
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
    assert_in_transaction!()
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
    assert_in_transaction!()
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

  #######################################################################
  ## TOOLS

  def cursor_advance({row, column}, columns) do
    [{:cursor, adjust_cursor({row, column + 1}, columns)}]
  end

  defp adjust_cursor({row, column}, columns) when column > columns, do: {row + 1, 1}

  defp adjust_cursor(cursor, _), do: cursor

  @spec transactionalize(:ets.table(), (() -> any)) :: any
  # this might be a terrible idea.  Consider using atomics, or wrapping the ets table
  # into a gen_server.
  def transactionalize(table, action) do
    transaction_lock = make_ref()

    if :ets.insert_new(table, {:transaction, transaction_lock}) do
      Process.put(:exterm_transaction, transaction_lock)
      result = action.()
      notify_waiters(table)
      :ets.delete(table, :transaction)
      Process.delete(:exterm_transaction)
      result
    else
      :ets.insert(table, {transaction_lock, self()})
      wait_for(transaction_lock)
      transactionalize(table, action)
    end
  end

  @compile {:inline, assert_in_transaction!: 0}
  defp assert_in_transaction!,
    do: Process.get(:exterm_transaction) || raise("this function needs to be in a transaction")

  defp notify_waiters(table) do
    table
    |> :ets.select([{{@key, @value}, [{:is_reference, @key}], [{{@key, @value}}]}])
    |> Enum.each(fn {transaction_lock, pid} -> send(pid, {:exterm_release, transaction_lock}) end)

    :ets.select_delete(table, [{{@key, @value}, [{:is_reference, @key}], [true]}])
  end

  defp wait_for(transaction_lock) do
    receive do
      {:exterm_release, ^transaction_lock} ->
        :ok
    after
      10 ->
        :ok
    end

    flush_releases()
  end

  defp flush_releases do
    receive do
      {:exterm_release, _} -> flush_releases()
    after
      0 ->
        :ok
    end
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
