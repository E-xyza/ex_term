defmodule ExTermTest.FlokiTools do
  @moduledoc false

  alias ExTerm.Style

  def dump(content) do
    content
    |> Floki.find("#exterm-console")
    |> Floki.text()
  end

  def to_text(content) do
    content
    |> Floki.find("#exterm-console span")
    |> Enum.flat_map(&List.wrap(span_to_cell(&1)))
    |> IO.iodata_to_binary()
    |> String.trim_trailing("\n")
  end

  defp span_to_cell(span) do
    classes =
      span
      |> Floki.attribute("class")
      |> List.first()

    if classes =~ "exterm-cell-sentinel", do: "\n", else: Floki.text(span)
  end

  def cursor_location(content) do
    console = Floki.find(content, "#exterm-console")

    ~w[row column]
    |> Enum.map(fn dim ->
      console
      |> Floki.attribute("data-exterm-cursor-#{dim}")
      |> List.first()
      |> String.to_integer()
    end)
    |> List.to_tuple()
  end

  def cursor_active?(content) do
    match?([_], Floki.find(content, ".exterm-cursor-active"))
  end

  def char_at(content, row, column) do
    [{"span", _, cell_content}] = Floki.find(content, "#exterm-cell-#{row}-#{column}")
    IO.iodata_to_binary(cell_content)
  end

  def buffer_last(content) do
    [{"div", _, buffer_content}] = Floki.find(content, "#exterm-buffer")

    buffer_content
    |> List.last()
    |> Floki.text(buffer_content)
  end

  def style_at(content, row, column) do
    content
    |> Floki.find("#exterm-cell-#{row}-#{column}")
    |> Floki.attribute("style")
    |> List.first()
    |> Style.from_css()
  end
end
