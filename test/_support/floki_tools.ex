defmodule ExTermTest.FlokiTools do
  def line_to_text(content, number) do
    [{"div", _, line}] = Floki.find(content, "#exterm-row-#{number}")

    line
    |> Enum.map(fn {"div", _, content} -> content end)
    |> IO.iodata_to_binary()
  end

  def cursor_location(content) do
    [attr] =
      content
      |> Floki.find(".exterm-cursor")
      |> Floki.attribute("id")

    ["exterm", "cell", row, column] = String.split(attr, "-")

    {String.to_integer(row), String.to_integer(column)}
  end

  def cursor_active?(content) do
    match?([_], Floki.find(content, ".exterm-cursor-active"))
  end

  def char_at(content, row, column) do
    [{"div", _, cell_content}] = Floki.find(content, "#exterm-cell-#{row}-#{column}")
    IO.iodata_to_binary(cell_content)
  end

  def buffer_last(content) do
    [{"div", _, buffer_content}] = Floki.find(content, "#exterm-buffer")
    Floki.text(buffer_content)
  end
end
