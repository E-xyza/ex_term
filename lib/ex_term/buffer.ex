defmodule ExTerm.Buffer do
  @moduledoc false
  use Phoenix.LiveComponent
  alias ExTerm.Console.Row

  defstruct top_row: 1

  def render(assigns) do
    ~H"""
    <div id="exterm-buffer" phx-update="append">
      <%= for row <- @buffer do %>
      <Row.render row={row} cursor={nil} prompt={nil}/>
      <% end %>
    </div>
    """
  end
end
