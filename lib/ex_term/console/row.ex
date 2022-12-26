defmodule ExTerm.Console.Row do
  @moduledoc false
  use Phoenix.LiveComponent

  alias ExTerm.Console.Cell

  def render(assigns) do
    number = number(assigns.row)
    assigns = Map.put(assigns, :id, "exterm-row-#{number}")

    ~H"""
    <div id={@id} class="exterm-row">
      <%= for cell <- @row do %>
      <Cell.render cell={cell} cursor={@cursor} prompt={@prompt}/>
      <% end %>
    </div>
    """
  end

  def number([cell | _]), do: number(cell)
  def number({{row, _}, _}), do: row
end
