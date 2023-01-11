defmodule ExTerm.Console.Cell do
  @moduledoc false

  use Phoenix.Component

  def render(assigns = %{cell: {location = {row, column}, cell}, cursor: cursor}) do
    sentinel_class = if cell.char === "\n", do: "exterm-cell-sentinel"
    cursor_class = if location === cursor, do: "exterm-cell-cursor"
    class = ["exterm-cell", sentinel_class, cursor_class]

    assigns = assign(assigns, id: "exterm-cell-#{row}-#{column}", class: class, cell: cell)

    ~H"<span id={@id} class={@class} style={@cell.style}><%= @cell.char %></span>"
  end

  alias ExTerm.Style

  defstruct style: Style.new(), char: nil
  @type t :: %__MODULE__{style: Style.t(), char: nil | String.t()}
  def new, do: %__MODULE__{}

  def sentinel, do: %__MODULE__{char: "\n"}
end
