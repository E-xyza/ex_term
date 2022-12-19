defmodule ExTermTest.Tools do
  def floki_line_to_text([{"div", _, line}]) do
    line
    |> Enum.map(fn {"div", _, content} -> content end)
    |> IO.iodata_to_binary()
  end
end
