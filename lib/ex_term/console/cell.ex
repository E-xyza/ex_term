defmodule ExTerm.Console.Cell do
  @moduledoc false

  use Phoenix.Component

  alias ExTerm.Style
  defstruct style: Style.new(), char: nil
  @type t :: %__MODULE__{style: Style.t(), char: nil | String.t()}
  def new, do: %__MODULE__{}

  def render(%{cell: {{row, column}, cell}, cursor: cursor}) do
    cursor_style =
      List.wrap(
        if cursor == {row, column} do
          "exterm-cursor"
        end
      )

    assigns = %{
      id: "exterm-cell-#{row}-#{column}",
      classes: ["exterm-cell" | cursor_style],
      cell: cell
    }

    ~H(<div id={@id} class={@classes} style={@cell.style}><%= @cell.char %></div>)
  end
end
