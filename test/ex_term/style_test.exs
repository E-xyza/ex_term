defmodule ExTermTest.StyleTest do
  use ExUnit.Case, async: true

  alias ExTerm.Style

  describe "colors are identified" do
    colors = [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]

    for color <- colors do
      foreground_text = apply(IO.ANSI, color, []) <> "text"

      test "assigns foreground #{color} correctly" do
        assert {%{color: unquote(color)}, "text"} =
                 Style.from_ansi(unquote(foreground_text))
      end
    end
  end
end
