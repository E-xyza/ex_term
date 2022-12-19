defmodule ExTerm.Console do
  @moduledoc false

  # ExTerm.Console is a datastructure/component which describes the "console" region of
  # the ExTerm interface.  This is a (currently 80c x 40r) matrix of characters
  # which contain their own individual styling elements.  The console also
  # retains a cursor position, which can move around.

  # In the future, this will likely support arbitrary row/column counts.

  use Phoenix.Component

  alias ExTerm.Style
  alias ExTerm.Console.Cell
  alias ExTerm.Console.Cursor
  alias ExTerm.Console.Row

  @default_row_count 40
  @default_column_count 80

  @default_rows for row_index <- 1..@default_row_count,
                    into: %{},
                    do: {row_index, Row.new(@default_column_count)}

  # NOTE that the dimensions field is not descriptive of the datastructure in
  # the rows term, in the future if dimensions are changeable, they may be out
  # of sync, and the rows term should be considered authoritative.
  defstruct cursor: Cursor.new(),
            rows: @default_rows,
            dimensions: {@default_row_count, @default_column_count},
            style: Style.new()

  @type rows :: %{optional(pos_integer) => Row.t()}
  @type t :: %__MODULE__{cursor: Cursor.t(), rows: rows}

  def new, do: %__MODULE__{}

  def render(%{console: assigns}) do
    assigns = Map.merge(assigns, %{
      total_rows: map_size(assigns.rows)
    })

    ~H"""
    <div id="exterm-console">
      <%= for row_index <- 1..@total_rows do %>
        <Row.render row_index={row_index} row={@rows[row_index]} cursor={@cursor}/>
      <% end %>
    </div>
    """
  end

  def put_chars(console, chars), do: put_char_internal({console, []}, chars)

  defp put_char_internal(result, ""), do: result

  defp put_char_internal({console, buffer_so_far}, chars) do
    {head, rest} = String.next_grapheme(chars)

    console
    |> put_char_in_place(head)
    |> realign_cursor(buffer_so_far)
    |> put_char_internal(rest)
  end

  defp put_char_in_place(console = %{cursor: cursor}, "\n") do
    %{console | cursor: %{cursor | row: cursor.row + 1, column: 1}}
  end

  defp put_char_in_place(console = %{cursor: cursor}, char) do
    new_cell = %Cell{style: console.style, char: char}
    new_rows = put_in(console.rows, [cursor.row, cursor.column], new_cell)

    console
    |> Map.put(:rows, new_rows)
    |> advance_cursor
  end

  defp advance_cursor(console = %{cursor: cursor}) do
    %{console | cursor: %{cursor | column: cursor.column + 1}}
  end

  defp realign_cursor(console, buffer_so_far) do
    {console, buffer_so_far}
  end
end
