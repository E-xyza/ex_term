defmodule ExTerm.Buffer.Span do
  alias ExTerm.Style
  @enforce_keys [:content, :style]

  defstruct @enforce_keys

  @type t :: %__MODULE__{
    style: Style.t(),
    content: iodata
  }

  use Phoenix.Component

  def render(assigns) do
    ~H"<div style={@style}><%= @content %></div>"
  end
end
