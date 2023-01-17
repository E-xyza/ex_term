defmodule ExTermTest.Console.GetTest do
  use ExUnit.Case, async: true

  alias ExTerm.Console
  alias ExTerm.Console.Cell
  alias ExTerm.Console.Helpers
  require Helpers

  setup do
    console = Console.new(layout: {5, 5})

    # lay down a first row of empties
    Helpers.transaction console, :mutate do
      Console.new_row(console)
    end

    {:ok, console: console}
  end

  describe "when get is called with a single location" do
    test "and that doesn't exist on the console, it's nil", %{console: console} do
      Helpers.transaction console, :access do
        # column doesn't exist
        refute Console.get(console, {1, 7})
        # row doesn't exist
        refute Console.get(console, {2, 1})
      end
    end

    test "getting at end of line yields sentinel", %{console: console} do
      Helpers.transaction console, :access do
        assert Cell.sentinel() === Console.get(console, {1, 6})
      end
    end

    test "you can get a set value", %{console: console} do
      Helpers.transaction console, :mutate do
        assert %Cell{char: nil} === Console.get(console, {1, 1})

        Console.put_cell(console, {1, 1}, %Cell{char: "a"})

        assert %Cell{char: "a"} === Console.get(console, {1, 1})
      end
    end
  end
end
