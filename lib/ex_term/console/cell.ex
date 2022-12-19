defmodule ExTerm.Console.Cell do
  @moduledoc false

  use Phoenix.Component

  alias ExTerm.Style
  defstruct style: Style.new(), char: nil
  @type t :: %__MODULE__{style: Style.t(), char: nil | String.t()}
  def new, do: %__MODULE__{}

  def render(assigns) do
    assigns =
      Map.merge(assigns, %{
        id: "exterm-cell-#{assigns.row_index}-#{assigns.column_index}"
      })

    ~H"<div id={@id} style={@cell.style}><%= @cell.char %></div>"
  end
end
