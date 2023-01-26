defmodule ExTermTest.Console.PutCellTest do
  use ExUnit.Case, async: true

  alias ExTerm.Console
  alias ExTerm.Console.Cell
  alias ExTerm.Console.Helpers

  require Console
  require Helpers

  defp updates(update) do
    send(self(), update)
  end

  setup do
    console = Console.new(handle_update: &updates/1, layout: {5, 5})
    console = Helpers.transaction console, :mutate do
      Console.new_row(console)
    end
    {:ok, console: console}
  end

  describe "when you call put_cell/3" do
    test "it puts a cell", %{console: console} do
      Helpers.transaction console, :mutate do
        Console.put_cell(console, {1, 1}, %Cell{char: "a"})
      end

      assert_receive %{cursor: nil, changes: [{1, 1}]}

      Helpers.transaction console, :mutate do
        assert %{char: "a"} = Console.get(console, {1, 1})

        Console.put_cell(console, {1, 4}, %Cell{char: "b"})
      end

      assert_receive %{cursor: nil, changes: [{1, 4}]}

      Helpers.transaction console, :mutate do
        assert %{char: "b"} = Console.get(console, {1, 4})
      end
    end

    test "it raises if it can't put the cell, out of range for the row", %{console: console} do
      Helpers.transaction console, :mutate do
        assert_raise RuntimeError, "location {1, 6} is out of bounds of the console: column 6 is beyond the last column in row 1 (5)", fn ->
          Console.put_cell(console, {1, 6}, %Cell{char: "a"})
        end

        assert_raise RuntimeError, "location {1, 7} is out of bounds of the console: column 7 is beyond the last column in row 1 (5)", fn ->
          Console.put_cell(console, {1, 7}, %Cell{char: "a"})
        end

        assert_raise RuntimeError, "location {2, 1} is out of bounds of the console: row 2 is beyond the last row (1)", fn ->
          Console.put_cell(console, {2, 1}, %Cell{char: "a"})
        end
      end
    end

    test "it raises if it can't put the cell, out of row range"
  end

  describe "when you call put_cell/4 with cursor movement option" do
    test "it moves the cursor"
  end

  describe "when you call put_cell/4 with row filling" do
    test "it fills the row when the layout is bigger than the row layout"

    test "it doesn't change anything when the layout are the same"

    test "it doesn't change anything when the layout is smaller than the row layout"
  end
end
