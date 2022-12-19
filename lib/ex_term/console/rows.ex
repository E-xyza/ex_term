defmodule ExTerm.Console.Rows do
  @moduledoc false
  use Phoenix.Component

  alias ExTerm.Console.Row
  @type t :: %{optional(non_neg_integer) => Columns.t()}
  @spec new(non_neg_integer) :: t
  def new(rows \\ 40), do: for(row <- 0..(rows - 1), into: %{}, do: {row, Columns.new()})

  def render(assigns) do
    assigns = Map.merge(assigns, %{total_rows: map_size(assigns.row)})

    ~H"""
    <div id={@id}>
      <%= for row_index <- 1..@total_rows do %>
        <Row.render row_index={row_index} row={@rows[row_index]}/>
      <% end %>
    </div>
    """
  end
end
