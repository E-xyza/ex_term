defmodule ExTerm.Console do
  @moduledoc false

  # ExTerm.Console is a datastructure/component which describes the "console" region of
  # the ExTerm interface.  This is a (currently 80c x 40r) matrix of characters
  # which contain their own individual styling elements.  The console also
  # retains a cursor position, which can move around.

  # In the future, this will likely support arbitrary row/column counts.

  use Phoenix.Component

  alias ExTerm.Console.Cursor
  alias ExTerm.Console.Row

  @default_row_count 40
  @default_column_count 80

  @default_rows (for row_index <- 1..@default_row_count, into: %{}, do: {row_index, Row.new(@default_column_count)})

  # NOTE that the dimensions field is not descriptive of the datastructure in
  # the rows term, in the future if dimensions are changeable, they may be out
  # of sync, and the rows term should be considered authoritative.
  defstruct cursor: Cursor.new(), rows: @default_rows, dimensions: {@default_row_count, @default_column_count}

  @type rows :: %{optional(pos_integer) => Row.t()}
  @type t :: %__MODULE__{cursor: Cursor.t(), rows: rows}

  def new, do: %__MODULE__{}

  def render(%{console: assigns}) do
    assigns = Map.merge(assigns, %{total_rows: map_size(assigns.rows)})

    ~H"""
    <div id="exterm-console">
      <%= for row_index <- 1..@total_rows do %>
        <Row.render row_index={row_index} row={@rows[row_index]}/>
      <% end %>
    </div>
    """
  end
end
