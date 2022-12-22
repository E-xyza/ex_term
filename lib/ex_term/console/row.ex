defmodule ExTerm.Console.Row do
  use Phoenix.LiveComponent

  alias ExTerm.Console.Cell

  def render(assigns) do
    [{{index, _}, _} | _] = assigns.row
    assigns = Map.put(assigns, :id, "exterm-row-#{index}")

    ~H"""
    <div id={@id}>
      <%= for cell <- @row do %>
      <Cell.render cell={cell} cursor={@cursor}/>
      <% end %>
    </div>
    """
  end
end
