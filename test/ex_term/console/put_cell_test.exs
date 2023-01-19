defmodule ExTermTest.Console.PutCellTest do
  use ExUnit.Case, async: true

  describe "when you call put_cell/3" do
    test "it puts a cell"

    test "it raises if it can't put the cell"
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
