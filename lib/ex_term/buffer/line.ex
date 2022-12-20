defmodule ExTerm.Buffer.Line do
  use Phoenix.Component

  alias ExTerm.Buffer.Span
  alias ExTerm.Console.Cell

  @enforce_keys [:spans]
  defstruct @enforce_keys

  def render(assigns) do
    id = "exterm-buffer-#{assigns.index}"
    ~H"""
    <div class="exterm-row" id={id}><%= for span <- @line do %><Span.render style={span.style} content={span.content}/><% end %></div>
    """
  end

  def from_row(row) do
    row
    |> Enum.sort
    |> Enum.reduce([], &concat_content/2)
    |> Enum.reverse
  end

  @spec concat_content({non_neg_integer, Cell.t}, [Span.t]) :: [Span.t]
  defp concat_content({1, cell = %{char: char}}, []) do
    List.wrap(if char, do: %Span{style: cell.style, content: char})
  end

  defp concat_content({_, %{char: nil}}, spans), do: spans

  defp concat_content({_, %{style: style, char: char}}, [head = %{style: style} | rest]) do
    [%{head | content: [head.content | char]} | rest]
  end

  defp concat_content({_, cell}, spans_so_far) do
    [%Span{style: cell.style, content: [cell.content | cell.char]} | spans_so_far]
  end
end
