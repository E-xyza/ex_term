defmodule ExTerm.Console.Row do
  use Phoenix.Component
  alias ExTerm.Console.Cell

  @type t :: %{optional(pos_integer) => Cell.t()}

  @spec new(pos_integer) :: t
  def new(columns \\ 80),
    do: for(column_index <- 1..columns, into: %{}, do: {column_index, Cell.new()})

  def render(assigns) do
    assigns =
      Map.merge(assigns, %{
        id: "exterm-row-#{assigns.row_index}",
        total_columns: map_size(assigns.row)
      })

    ~H"""
    <div id={@id}>
      <%= for column_index <- 1..@total_columns do %><Cell.render row_index={@row_index} column_index={column_index} cell={@row[column_index]}/><% end %>
    </div>
    """
  end
end
