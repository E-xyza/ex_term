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
        id: "exterm-cell-#{assigns.row_index}-#{assigns.column_index}",
        classes: ["exterm-cell" | maybe_cursor(assigns)]
      })

    ~H(<div id={@id} class={@classes} style={@cell.style}><%= @cell.char %></div>)
  end

  defp maybe_cursor(%{
         cursor: %{row: row, column: column},
         row_index: row,
         column_index: column,
         prompt: prompt
       }) do
    [" exterm-cursor" | List.wrap(if prompt, do: " exterm-cursor-active")]
  end

  defp maybe_cursor(_), do: []
end
