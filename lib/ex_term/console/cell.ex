defmodule ExTerm.Console.Cell do
  @moduledoc false

  use Phoenix.Component

  def render(assigns = %{cell: {location = {row, column}, cell}, cursor: cursor}) do
    char = cell.char || " "

    sentinel_class =
      case cell.char do
        "\n" -> "exterm-cell-sentinel"
        " " -> "exterm-cell-space"
        nil -> "exterm-cell-blank"
        _ -> nil
      end

    cursor_class =
      case {location === cursor, assigns.prompt} do
        {true, true} -> "exterm-cursor-active"
        {true, _} -> "exterm-cursor"
        _ -> nil
      end

    class = ["exterm-cell", sentinel_class, cursor_class]

    assigns = %{id: "exterm-cell-#{row}-#{column}", class: class, style: cell.style, char: char}

    ~H"<span id={@id} class={@class} style={@style} contenteditable='false'><%= @char %></span>"
  end

  alias ExTerm.Style

  defstruct style: Style.new(), char: nil
  @type t :: %__MODULE__{style: Style.t(), char: nil | String.t()}
  def new, do: %__MODULE__{}

  def sentinel, do: %__MODULE__{char: "\n"}
end
