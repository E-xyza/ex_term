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
  alias ExTerm.Style

  import ExTerm.Console.Helpers

  @type permission :: :private | :protected | :public
  @opaque t ::
            {:private | :protected, pid, :ets.table()}
            | {:public, pid, :ets.table(), :atomics.atomics_ref()}
  @type location :: {pos_integer(), pos_integer()}

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

  #@spec put_chars(t, String.t()) :: t
  #@spec push_key(t, String.t()) :: boolean

  #############################################################################
  ## GUARDS

  @spec permission(t) :: permission
  defguard permission(console) when elem(console, 0)

  @spec custodian(t) :: pid
  defguard custodian(console) when elem(console, 1)

  @spec spinlock(t) :: :atomics.atomics_ref()
  defguard spinlock(console) when elem(console, 3)

  @spec is_access_ok(t) :: boolean
  defguard is_access_ok(console)
            when permission(console) in [:public, :private] or self() === custodian(console)

  @spec is_mutate_ok(t) :: boolean
  defguard is_mutate_ok(console)
            when permission(console) === :public or self() === custodian(console)

  @spec is_local(t) :: boolean
  defguard is_local(console) when node(custodian(console)) === node()

  defp table(console), do: elem(console, 2)

  #############################################################################
  ## CONSOLE ETS interactions

  @spec new(keyword) :: t
  def new(opts \\ []) do
    permission = Keyword.get(opts, :permission, :protected)
    {rows, columns} = layout = Keyword.get(opts, :layout, {24, 80})
    table = :ets.new(__MODULE__, [permission, :ordered_set])

    console =
      case permission do
        :public -> {:public, self(), table, :atomics.new(1, signed: false)}
        _ -> {permission, self(), table}
      end

    cells = for row <- 1..rows, column <- 1..columns, do: {{row, column}, Cell.new()}

    :ets.insert(table, cells)

    transaction(console, :mutate) do
      put_metadata(console, layout: layout, cursor: {1, 1}, style: %Style{})
    end
  end

  @spec layout(t) :: location
  def layout(console) do
    transaction(console, :access) do
      metadata(console, :layout)
    end
  end

  @spec cursor(t) :: location
  def cursor(console) do
    transaction(console, :access) do
      metadata(console, :cursor)
    end
  end

  @spec style(t) :: Style.t
  def style(console) do
    transaction(console, :access) do
      metadata(console, :style)
    end
  end

  # basic access functions

  defmatchspecp get_ms({key, value}) do
    {{^key, ^value}, cell} -> cell
  end

  @spec get(t, location) :: nil | Cell.t()
  defaccess get(console, location) do
    console
    |> table
    |> :ets.select(get_ms(location))
    |> case do
      [cell] -> cell
      [] -> nil
    end
  end

  defmatchspecp metadata_ms(key) do
    {^key, value} -> value
  end

  @spec metadata(t, atom) :: term
  defaccess metadata(console, key) do
    console
    |> table
    |> :ets.select(metadata_ms(key))
    |> List.first()
  end

  # basic mutations

  @spec put_metadata(t, term, term) :: t
  defmut put_metadata(console, key, value) do
    console
    |> table
    |> :ets.insert([{key, value}])

    console
  end

  @spec put_metadata(t, keyword) :: t
  defmut put_metadata(console, keyword) do
    console
    |> table
    |> :ets.insert(keyword)

    console
  end

  @spec put_char(t, location, Cell.t()) :: t
  defmut put_char(console, location, char) do
    console
    |> table()
    |> :ets.insert({location, char})
  end
end
