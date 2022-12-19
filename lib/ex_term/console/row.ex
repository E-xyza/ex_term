defmodule ExTerm.Console.Row do
  use Phoenix.Component
  alias ExTerm.Console.Cell
  @type t :: %{optional(non_neg_integer) => Cell.t()}
  @spec new(non_neg_integer) :: t
  def new(columns \\ 80), do: for(column <- 0..(columns - 1), into: %{}, do: {column, Cell.new()})

  def render(assigns) do
    assigns =
      Map.merge(assigns, %{
        id: "exterm-row-#{assigns.index}",
        total_columns: map_size(assigns.row)
      })

    ~H"""
    <div id={@id}>
      <%= for column_index <- 1..@total_columns do %><Cell.render row_index={@row_index} column_index={column_index} cell={@row[@row_index]}/><% end %>
    </div>
    """
  end
end
