defmodule ExTerm.Console.Cell do
  @moduledoc false

  use Phoenix.Component

  alias ExTerm.Style
  defstruct style: Style.new(), char: nil
  @type t :: %__MODULE__{style: Style.t(), char: nil | String.t()}
  def new, do: %__MODULE__{}

  def render(%{cell: {rc = {row, column}, cell}, cursor: cursor, prompt: prompt}) do
    cursor_style =
      case {cursor, prompt} do
        {^rc, true} -> ["exterm-cursor ", "exterm-cursor-active "]
        {^rc, false} -> ["exterm-cursor "]
        _ -> []
      end

    assigns = %{
      id: "exterm-cell-#{row}-#{column}",
      classes: ["exterm-cell " | cursor_style],
      cell: cell
    }

    ~H(<div id={@id} class={@classes} style={@cell.style}><%= @cell.char %></div>)
  end
end
