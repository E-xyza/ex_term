defmodule ExTerm.Console do
  @moduledoc """
  A datastructure which describes in-memory storage of console information.

  Console information consists of the following:

  - buffer of all rows/columns so far.
  - view window sizing metadata.
  - cursor location.
  - current ANSI styling metadata.

  You may also store custom metadata into console.

  Console is backed by an ets table.  Access functions are designed to operate
  across a cluster.  Note that console is not backed by a process, but it is the
  responsibility of a process; if that process dies, the console will get destroyed,
  and by default mutating functions cannot be called from other processes.
  """

  use Phoenix.Component
  use MatchSpec

  alias ExTerm.Console.Cell
  alias ExTerm.Console.Row
  alias ExTerm.Console.StringTracker
  alias ExTerm.Style

  import ExTerm.Console.Helpers

  @type permission :: :private | :protected | :public
  @opaque t ::
            {:private | :protected, pid, :ets.table()}
            | {:public, pid, :ets.table(), :atomics.atomics_ref()}
  @type location :: {pos_integer(), pos_integer()}
  @type update :: {from :: location, to :: location, last_cell :: location}
  @type cellinfo :: {location, Cell.t}

  # message typing
  @type update_msg :: {:update, update}
  defmacro update_msg(payload) do
    quote do {:update, unquote(payload) = {{_, _}, {_, _}, {_, _}}} end
  end

  ############################################################################
  ## rendering function

  def render(assigns) do
    ~H"""
    <div id="exterm-console" phx-update="append">
      <%= for row <- @rows do %>
      <Row.render row={row} cursor={@cursor} prompt={@prompt} location="console"/>
      <% end %>
    </div>
    """
  end

  #############################################################################
  ## API

  #############################################################################
  ## GUARDS

  defguard permission(console) when elem(console, 0)

  defguard custodian(console) when elem(console, 1)

  defguard spinlock(console) when elem(console, 3)

  defguard is_access_ok(console)
           when permission(console) in [:public, :private] or self() === custodian(console)

  defguard is_mutate_ok(console)
           when permission(console) === :public or self() === custodian(console)

  defguard is_local(console) when node(custodian(console)) === node()

  defp table(console), do: elem(console, 2)

  #############################################################################
  ## CONSOLE ETS interactions

  @spec new(keyword) :: t
  def new(opts \\ []) do
    permission = Keyword.get(opts, :permission, :protected)
    {rows, columns} = layout = Keyword.get(opts, :layout, {24, 80})
    update_handler = Keyword.get(opts, :handle_update)
    table = :ets.new(__MODULE__, [permission, :ordered_set])

    console =
      case permission do
        :public -> {:public, self(), table, :atomics.new(1, signed: false)}
        _ -> {permission, self(), table}
      end

    end_col = columns + 1

    cells =
      for row <- 1..rows,
          column <- 1..end_col,
          do: {{row, column}, %Cell{char: if(column === end_col, do: "\n")}}

    transaction(console, :mutate) do
      console
      |> insert(cells)
      |> put_metadata(
        layout: layout,
        cursor: {1, 1},
        style: %Style{},
        handle_update: update_handler
      )
    end
  end

  @spec layout(t) :: location
  def layout(console) do
    transaction(console, :access) do
      get_metadata(console, :layout)
    end
  end

  @spec cursor(t) :: location
  def cursor(console) do
    transaction(console, :access) do
      get_metadata(console, :cursor)
    end
  end

  @spec style(t) :: Style.t()
  def style(console) do
    transaction(console, :access) do
      get_metadata(console, :style)
    end
  end

  # basic access functions

  defmatchspecp get_ms({key, value}) do
    {{^key, ^value}, cell} -> cell
  end

  @spec get(t, location) :: nil | Cell.t()
  def get(console, location) do
    console
    |> select(get_ms(location))
    |> case do
      [cell] -> cell
      [] -> nil
    end
  end

  defmatchspecp metadata_ms(key) when is_atom(key) do
    {^key, value} -> value
  end

  defmatchspecp metadata_ms(keys) when is_list(keys) do
    tuple = {key, _} when key in keys -> tuple
  end

  @spec get_metadata(t, atom | [atom]) :: term
  @doc """
  obtains a single key metadata or a list of keys.

  Note that the keys will be returned in erlang term order.
  """
  def get_metadata(console, key) do
    case select(console, metadata_ms(key)) do
      list when is_atom(key) -> List.first(list)
      list -> list
    end
  end

  # basic mutations

  @spec put_metadata(t, term, term) :: t
  def put_metadata(console, key, value) do
    insert(console, [{key, value}])
  end

  @spec put_metadata(t, keyword) :: t
  def put_metadata(console, keyword) do
    insert(console, keyword)
  end

  @spec delete_metadata(t, keyword) :: t
  def delete_metadata(console, key) do
    delete(console, key)
  end

  @spec put_cell(t, location, Cell.t()) :: t
  def put_cell(console, location, char) do
    insert(console, {location, char})
  end

  # compound operations
  defmatchspecp bump_rows_after(line) do
    {{row, column}, cell} when row >= line -> {{row + 1, column}, cell}
  end

  @spec new_row(t, pos_integer() | :end) :: t
  def new_row(console, insertion_at \\ :end)

  def new_row(console, :end) do
    {row, _} = last_location(console)
    new_row = row + 1
    {_rows, columns} = get_metadata(console, :layout)

    # note it's okay to put that last one out of order because ets will
    # order it correctly.
    console
    |> insert(make_blank_row(new_row, columns))
    |> update_with({{new_row, 1}, {new_row, columns + 1}, {new_row, columns}})
  end

  def new_row(console, line) when is_integer(line) do
    new_row_columns = columns(console, line)
    {last_row, last_column} = last_location(console)

    moved_rows = select(console, bump_rows_after(line))

    update = line
    |> make_blank_row(new_row_columns)
    |> Enum.reverse(moved_rows)

    console
    |> insert(update)
    |> update_with({{line, 1}, {last_row + 1, last_column}, {last_row + 1, last_column - 1}})
  end

  @spec put_string(t, String.t) :: t
  def put_string(console, string) do
    # first, obtain the cursor location.
    # next obtain the
    {last_row, last_column} = last_location(console)
    tracker = StringTracker.new(console)

    updated = put_string_rows(tracker, string)

    console
    |> insert(updated.updates)
    |> update_with({tracker.cursor, updated.last_updated, {last_row, last_column - 1}})
    |> put_metadata(:cursor, updated.cursor)
  end

  @spec put_string_rows(t, StringTracker.t) :: StringTracker.t
  defp put_string_rows(tracker = %{cursor: {row, _}}, string) do
    columns = columns(tracker.console, row)
    case put_string_row(tracker, columns, string) do
      # exhausted the row without finishing the string
      {updated_tracker, leftover} ->
        put_string_rows(%{updated_tracker | cursor: {row + 1, 1}}, leftover)
      done -> done
    end
  end

  defp put_string_row(tracker = %{cursor: {_, column}}, columns, string) when column === columns + 1 do
    {tracker, string}
  end

  defp put_string_row(tracker = %{cursor: cursor = {row, column}}, columns, string) do
    case String.next_grapheme(string) do
      nil ->
        tracker
      {grapheme, rest} ->
        updates = [{cursor, %Cell{char: grapheme, style: tracker.style}} | tracker.updates]
        put_string_row(%{tracker | cursor: {row, column + 1}, last_updated: cursor, updates: updates}, columns, rest)
    end
  end

  # functional utilities

  @spec update_with(t, update) :: t
  defp update_with(console, update) do
    case get_metadata(console, :handle_update) do
      fun when is_function(fun, 1) ->
        fun.(update)

      nil ->
        :ok

      other ->
        raise "invalid update handler, expected arity 1 fun, got #{inspect(other)}"
    end

    console
  end

  @spec select(t, :ets.match_spec) :: [tuple]
  defaccess select(console, ms) do
    console
    |> table()
    |> :ets.select(ms)
  end

  @spec insert(t, tuple | [tuple]) :: t
  defmutate insert(console, content) do
    console
    |> table()
    |> :ets.insert(content)

    console
  end

  @spec delete(t, atom) :: t
  defmutate delete(console, key) do
    console
    |> table
    |> :ets.delete(key)

    console
  end

  # activate when 0.3.1 hits, see https://github.com/E-xyza/match_spec/issues/28

  #defmatchspecp column_count(row) do
  #  {{^row, _}, cell} when cell.char !== "\n" -> true
  #end

  defp column_count(row) do
    [{{{row, :_}, :"$1"}, [{:"=/=", {:map_get, :char, :"$1"}, {:const, "\n"}}], [true]}]
  end

  @spec columns(t, pos_integer) :: pos_integer
  defaccess columns(console, row) do
    console
    |> table()
    |> :ets.select_count(column_count(row))
  end

  @spec last_location(t) :: location
  defp last_location(console) do
    # the last item in the table encodes the last row because the ordered
    # set is ordered based on erlang term order and erlang term order puts tuples
    # behind atoms, which are the only two types in the table.
    console
    |> table()
    |> :ets.last()
  end

  defp make_blank_row(row, columns) do
    [
      {{row, columns + 1}, %Cell{char: "\n"}}
      | for column <- 1..columns do
          {{row, column}, %Cell{}}
        end
    ]
  end
end
