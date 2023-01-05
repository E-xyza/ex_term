defmodule ExTermTest.ConsoleTest do
  use ExUnit.Case, async: true

  alias ExTerm.Console
  alias ExTerm.Style

  describe "when you make a console" do
    test "it produces an 24x80 layout by default" do
      console = Console.new()

      assert {24, 80} == Console.layout(console)
      assert {1, 1} == Console.cursor(console)
      assert %Style{} == Console.style(console)

      for row <- 1..24, column <- 1..80 do
        assert %{char: nil} = Console.get(console, {row, column})
      end

      for row <- 1..24, do: assert is_nil(Console.get(console, {row, 81}))
      assert is_nil(Console.get(console, {25, 1}))
    end

    test "you can customize the layout" do
      console = Console.new(layout: {5, 5})

      assert {5, 5} == Console.layout(console)

      for row <- 1..5, column <- 1..5 do
        assert %{char: nil} = Console.get(console, {row, column})
      end

      for row <- 1..5, do: assert is_nil(Console.get(console, {row, 6}))
      assert is_nil(Console.get(console, {6, 1}))
    end
  end

  describe "console metadata" do

  end
end
