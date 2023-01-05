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
  @opaque t :: {permission, pid, :ets.table()}
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

  @spec put_chars(t, String.t()) :: t
  @spec push_key(t, String.t()) :: boolean

  @spec permission(t) :: permission
  defguardp permission(console) when elem(console, 0)

  @spec custodian(t) :: pid
  defguardp custodian(console) when elem(console, 1)

  @spec is_accessible(t) :: boolean
  defguardp is_accessible(console) when permission(console) in [:public, :private] or self() === custodian(console)

  @spec is_mutable(t) :: boolean
  defguardp is_mutable(console) when permission(console) === :public or self() === custodian(console)

  defp table(console), do: elem(console, 2)

  #############################################################################
  ## CONSOLE ETS interactions

  @spec new(keyword) :: t
  def new(opts \\ []) do
    permission = Keyword.get(opts, :permission, :protected)
    {rows, columns} = layout = Keyword.get(opts, :layout, {24, 80})
    table = :ets.new(__MODULE__, [permission, :ordered_set])
    console = {permission, self(), table}

    cells = for row <- 1..rows, column <- 1..columns, do: {{row, column}, Cell.new()}

    :ets.insert(table, cells)

    put_metadata(console, layout: layout, cursor: {1, 1}, style: %Style{})
  end

  @spec layout(t) :: location
  def layout(console) do
    metadata(console, :layout)
  end

  @spec cursor(t) :: location
  def cursor(console) do
    metadata(console, :cursor)
  end

  def style(console) do
    metadata(console, :style)
  end

  defmatchspecp get_ms({key, value}) do
    {{^key, ^value}, cell} -> cell
  end

  @spec get(t, location) :: nil | Cell.t
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
    |> List.first
  end

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




  def put_chars(console, chars) do
    do_put_char(console, chars)
  end

  def push_key(console, key) do
    do_put_char(console, key)
  end

  #############################################################################
  ## COMMON FUNCTIONS

  defp do_put_char(result, ""), do: result

  @control 27

  defp do_put_char(console, chars = <<@control, _::binary>>) do
    style = Data.metadata(console, :style)
    {style, rest} = Style.from_ansi(style, chars)
    Data.put_metadata(console, style: style)

    do_put_char(console, rest)
  end

  defp do_put_char(console, chars) do
    {head, rest} = String.next_grapheme(chars)

    console
    |> put_char_in_place(head)
    |> do_put_char(rest)
  end

  defp put_char_in_place(console, "\n"), do: cursor_crlf(console)

  defp put_char_in_place(console, char) do
    Data.put_char(console, char)
  end

  defdelegate cursor_advance(console, columns), to: Data
  defdelegate cursor_crlf(console), to: Data
  defdelegate paint_chars(console, location, content, cursor_offset), to: Data
end
