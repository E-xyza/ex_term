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
  alias ExTerm.Console.StringTracker
  alias ExTerm.Console.Update
  alias ExTerm.Style

  import ExTerm.Console.Helpers

  @type permission :: :private | :protected | :public
  @opaque t ::
            {:private | :protected, pid, :ets.table()}
            | {:public, pid, :ets.table(), :atomics.atomics_ref()}
  @type location :: {pos_integer(), pos_integer()}
  @type layout :: location | {0, 0}
  @type update ::
          {:xterm_console_update, from :: location, to :: location, cursor :: location,
           last_cell :: location}
  @type cellinfo :: {location, Cell.t()}

  ############################################################################
  ## rendering function

  def render(assigns) do
    ~H"""
    <div id="exterm-console" phx-update="append" data-exterm-cursor-row={elem(@cursor, 0)} data-exterm-cursor-column={elem(@cursor, 1)}>
      <Cell.render contenteditable="false" :for={cell <- @cells} cell={cell} cursor={@cursor} prompt={@prompt}/>
    </div>
    """
  end

  #############################################################################
  ## API

  @spec new(keyword) :: t

  # metadata access
  @spec layout(t) :: location
  @spec cursor(t) :: location
  @spec style(t) :: Style.t()
  @spec get_metadata(t, atom | [atom]) :: term

  # metadata mutations
  @spec put_metadata(t, atom, term) :: t
  @spec put_metadata(t, keyword) :: t
  @spec delete_metadata(t, atom) :: t

  @spec move_cursor(t, location) :: t

  # cell access
  @spec get(t, location) :: nil | Cell.t()

  # primitive cell mutation
  @spec put_cell(t, location, Cell.t()) :: t
  @spec new_row(t, pos_integer() | :end) :: t

  # complex cell mutation
  @spec put_iodata(t, iodata) :: :ok
  @spec insert_iodata(t, iodata, row :: pos_integer()) :: Range.t()

  #############################################################################
  ## GUARDS

  defguard permission(console) when elem(console, 0)

  defguard custodian(console) when elem(console, 1)

  defguard spinlock(console) when elem(console, 3)

  defguard is_access_ok(console)
           when permission(console) in [:public, :protected] or self() === custodian(console)

  defguard is_mutate_ok(console)
           when permission(console) === :public or self() === custodian(console)

  defguard is_local(console) when node(custodian(console)) === node()

  defguard location(cellinfo) when elem(cellinfo, 0)

  #############################################################################
  ## CONSOLE ETS interactions

  def new(opts \\ []) do
    permission = Keyword.get(opts, :permission, :protected)
    layout = Keyword.get(opts, :layout, {24, 80})
    update_handler = Keyword.get(opts, :handle_update)
    table = :ets.new(__MODULE__, [permission, :ordered_set])

    console =
      case permission do
        :public -> {:public, self(), table, :atomics.new(1, signed: false)}
        _ -> {permission, self(), table}
      end

    transaction(console, :mutate) do
      put_metadata(console,
        layout: layout,
        cursor: {1, 1},
        style: %Style{},
        handle_update: update_handler
      )
    end
  end

  def layout(console) do
    get_metadata(console, :layout)
  end

  def cursor(console) do
    get_metadata(console, :cursor)
  end

  def style(console) do
    get_metadata(console, :style)
  end

  # basic access functions

  require Update

  defmatchspecp get_ms(location) when Update.is_location(location) do
    {^location, cell} -> cell
  end

  def get(console, location) when Update.is_location(location) do
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

  @doc """
  obtains a single key metadata or a list of keys.

  Note that if you provide a list of keys the values will be returned as a
  keyword list, in erlang term order of the keys.
  """
  def get_metadata(console, key) do
    case select(console, metadata_ms(key)) do
      list when is_atom(key) -> List.first(list)
      list -> list
    end
  end

  # basic mutations

  def put_metadata(console, key, value) do
    insert(console, [{key, value}])
  end

  def put_metadata(console, keyword) do
    insert(console, keyword)
  end

  def delete_metadata(console, key) do
    delete(console, key)
  end

  def put_cell(console, location = {row, column}, char) do
    # verify that the location is inside the limits
    case columns(console, row) do
      0 ->
        {last_row, _} = last_cell(console)

        raise "location #{inspect(location)} is out of bounds of the console: row #{row} is beyond the last row (#{last_row})"

      columns when column > columns ->
        raise "location #{inspect(location)} is out of bounds of the console: column #{column} is beyond the last column in row #{row} (#{columns})"

      _ ->
        :ok
    end

    Update.register_cell_change(console, location)
    insert(console, {location, char})
  end

  defmatchspecp rows_from(starting_row) do
    tuple = {{row, _}, cell} when row >= starting_row -> tuple
  end

  def new_row(console, insertion_at \\ :end)

  def new_row(console, :end) do
    {row, _} = last_cell(console)
    new_row = row + 1
    {_rows, columns} = layout(console)
    Update.register_cell_change(console, {{new_row, 1}, {new_row, :end}})

    insert(console, make_blank_row(new_row, columns))
  end

  def new_row(console, row) when is_integer(row) do
    # does row exist?
    new_row_columns =
      case columns(console, row) do
        0 ->
          raise "attempted to insert row into row #{row} but the destination does not exist"

        columns ->
          columns
      end

    # note that if the console cursor row is bigger than the row we'll need to move it.
    case cursor(console) do
      {cursor_row, cursor_column} when cursor_row >= row ->
        Update.change_cursor({cursor_row + 1, cursor_column})

      _ ->
        :ok
    end

    # register the update that we will need to do.
    Update.register_cell_change(console, {{row, 1}, :end})

    moved_rows = _bump_rows(console, row, 1)

    insertion =
      1..new_row_columns
      |> Enum.reduce(moved_rows, fn index, so_far ->
        [{{row, index}, %Cell{}} | so_far]
      end)
      |> List.insert_at(0, {{row, new_row_columns + 1}, Cell.sentinel()})

    insert(console, insertion)
  end

  @spec _bump_rows(t, pos_integer, pos_integer) :: [cellinfo]
  @doc false
  def _bump_rows(console, from_row, count) do
    grouped_rows =
      console
      |> select(rows_from(from_row))
      |> Enum.group_by(&elem(location(&1), 0))

    Enum.flat_map(grouped_rows, fn
      {row, list} when is_map_key(grouped_rows, row + count) ->
        # when the row exists, then we have to conform to the length of the
        # target row.  Truncate to that length.
        list
        |> Enum.zip(grouped_rows[row + count])
        |> Enum.map(fn
          # sentinel for destination row
          {_, dest = {_, %{char: "\n"}}} -> dest
          # sentinel for source row
          {{_, %{char: "\n"}}, dest} -> dest
          {{{row, col}, cell}, _} -> {{row + count, col}, cell}
        end)

      {_, list} ->
        # last line gets copied over outright
        Enum.map(list, fn {{row, col}, cell} -> {{row + count, col}, cell} end)
    end)
  end

  @doc """
  `inserts` iodata at the location of a cursor.
  """
  def put_iodata(console, iodata) do
    console
    |> StringTracker.new()
    |> StringTracker.put_string_rows(IO.iodata_to_binary(iodata))
    |> StringTracker.flush_updates()
  end

  @doc """
  `inserts` iodata at a certain row.

  This will "push down" as many lines as is necessary to insert the iodata.
  If the current cursor precedes the insertion point, it will be unaffected.
  If the current cursor is after the insertion point, it will be displaced
  as many lines as are necessary
  """
  def insert_iodata(console, iodata, row) do
    # the claim here is that everything after a given location must be broadcast.
    Update.register_cell_change(console, {{row, 1}, :end})

    string =
      iodata
      |> IO.iodata_to_binary()
      |> String.replace_suffix("\n", "")

    console
    |> StringTracker.new(row)
    |> StringTracker.insert_string_rows(string)
    |> StringTracker.flush_updates()
  end

  defmatchspecp cell_range_ms(row, column_start, row, column_end) do
    tuple = {{^row, column}, _} when column >= column_start and column <= column_end -> tuple
  end

  defmatchspecp cell_range_ms(row_start, column_start, row_end, column_end)
                when row_start + 1 === row_end do
    tuple = {{^row_start, column}, cell} when column >= column_start ->
      tuple

    tuple = {{^row_end, column}, _} when column <= column_end ->
      tuple
  end

  defmatchspecp cell_range_ms(row_start, column_start, row_end, column_end) do
    tuple = {{^row_start, column}, cell} when column >= column_start ->
      tuple

    tuple = {{^row_end, column}, _} when column <= column_end ->
      tuple

    tuple = {{row, column}, cell} when row > row_start and row < row_end ->
      tuple
  end

  defmatchspecp cells_from(location) do
    tuple = {this, cell} when this >= location -> tuple
  end

  def move_cursor(console, new_cursor = {row, column}) do
    old_cursor = cursor(console)

    if old_cursor === new_cursor do
      console
    else
      changes =
        case {last_cell(console), has?(console, new_cursor)} do
          {_, true} ->
            [old_cursor, new_cursor]

          {{last_row, _}, false} when last_row + 1 === row and column === 1 ->
            [old_cursor]

          {last, false} ->
            raise "cursor move to #{inspect(new_cursor)} exceeded the console buffer (#{move_msg(console, last, new_cursor)})"
        end

      Update.change_cursor(new_cursor)

      console
      |> Update.register_cell_change(changes)
      |> put_metadata(:cursor, new_cursor)
    end
  end

  def move_msg(_, {last_row, _}, {cursor_row, _}) when cursor_row > last_row do
    "cursor row #{cursor_row} is beyond the last console row #{last_row}"
  end

  def move_msg(console, _, {cursor_row, cursor_col}) do
    "cursor column #{cursor_col} is beyond the last column of row #{cursor_row}: #{columns(console, cursor_row)}"
  end

  # functional utilities
  @doc false
  # this is for internal use only.
  def broadcast(console, update) do
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

  defmatchspecp column_count_ms(row) do
    {{^row, _}, cell} when cell.char !== "\n" -> true
  end

  defmatchspecp full_row_ms(row, true) do
    tuple = {{^row, _}, _} -> tuple
  end

  defmatchspecp full_row_ms(row, false) do
    tuple = {{^row, _}, cell} when cell.char !== "\n" -> tuple
  end

  @spec columns(t, row :: pos_integer) :: non_neg_integer
  @doc """
  returns the number of columns in a given row.

  Does not include the sentinel in the final count.

  If the row doesn't exist, returns 0.
  """
  def columns(console, row) do
    select_count(console, column_count_ms(row))
  end

  @spec full_row(t, row :: pos_integer, with_sentinel? :: boolean) :: [cellinfo]
  @doc """
  returns a full row, in ascending order.

  May include the sentinel, if `with_sentinel?` is `true` (defaults to `false`)
  """
  def full_row(console, row, with_sentinel? \\ false) do
    select(console, full_row_ms(row, with_sentinel?))
  end

  @spec has?(t, location) :: boolean
  def has?(console, location) do
    not is_nil(lookup(console, location))
  end

  @spec last_column?(t, location) :: boolean
  @doc """
  returns true if the cell exists and the location is on the last column of its
  row, not inclusive of the sentinel.  Note this returns false if it's the
  sentinel.
  """
  def last_column?(console, {row, column}) do
    match?({_, %{char: "\n"}}, lookup(console, {row, column + 1}))
  end

  @spec last_cell(t) :: layout
  @doc """
  returns the last location on the console.

  Does NOT include the sentinel.  There is always guaranteed to be a sentinel
  on the end of the cell.

  If the table is empty and only contains metadata, returns `{0, 0}`
  """
  def last_cell(console) do
    # the last key in the table encodes the last row because the ordered
    # set is ordered based on erlang term order and erlang term order puts tuples
    # behind atoms, which are the only two types in the table.
    case last(console) do
      {row, column} -> {row, column - 1}
      metadata when is_atom(metadata) -> {0, 0}
    end
  end

  # generic access functions

  @spec last(t) :: location | atom
  defaccess last(console) do
    console
    |> table()
    |> :ets.last()
  end

  @spec lookup(t, location) :: cellinfo | nil
  defaccess lookup(console, location) do
    console
    |> table()
    |> :ets.lookup(location)
    |> case do
      [cell] -> cell
      [] -> nil
    end
  end

  @spec select(t, :ets.match_spec()) :: [cellinfo]
  defaccess select(console, ms) do
    console
    |> table()
    |> :ets.select(ms)
  end

  @spec select_count(t, :ets.match_spec()) :: non_neg_integer
  defaccess select_count(console, ms) do
    console
    |> table
    |> :ets.select_count(ms)
  end

  @spec select_from(t, Console.location()) :: [cellinfo]
  defaccess select_from(console, location) do
    console
    |> table
    |> :ets.select(cells_from(location))
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

  # other commonly usable functions
  def make_blank_row(row, columns) do
    [
      {{row, columns + 1}, Cell.sentinel()}
      | for column <- 1..columns do
          {{row, column}, %Cell{}}
        end
    ]
  end

  defp table(console), do: elem(console, 2)
end
