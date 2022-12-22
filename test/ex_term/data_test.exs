defmodule ExTermTest.DataTest do
  use ExUnit.Case, async: true

  alias ExTerm.Console.Cell
  alias ExTerm.Console.Data
  alias ExTerm.Style

  describe "metadata query" do
    setup do
      {:ok, table: Data.new()}
    end

    test "works to get all data", %{table: table} do
      # note the following KWL is ordered.
      assert [columns: 80, cursor: {1, 1}, rows: 40, style: Style.new()] == Data.metadata(table)
    end

    test "works to get single data", %{table: table} do
      assert Style.new() == Data.metadata(table, :style)
    end

    test "works to get multiple data", %{table: table} do
      # note the following KWL is ordered.
      assert [80, {1, 1}] == Data.metadata(table, [:columns, :cursor])
    end
  end

  describe "console query" do
    test "works in the base case" do
      table = Data.new()
      expected = for row <- 1..40, column <- 1..80, do: {{row, column}, Cell.new()}
      assert {{1, 1}, expected} == Data.console(table)
    end
  end

  describe "cursor_crlf" do
    setup do
      {:ok, table: Data.new(rows: 4, columns: 4)}
    end

    defp do_crlf(table) do
      Data.transactionalize(table, fn ->
        Data.cursor_crlf(table)
      end)
    end

    test "moves the cursor down one row", %{table: table} do
      do_crlf(table)
      assert {2, 1} = Data.metadata(table, :cursor)
    end

    test "always puts the column at one", %{table: table} do
      Data.metadata(table, :cursor, {2, 3})
      do_crlf(table)
      assert {3, 1} = Data.metadata(table, :cursor)
    end

    test "if we go beyond the existing rows it adds a new one", %{table: table} do
      Data.metadata(table, :cursor, {4, 1})
      do_crlf(table)
      assert {5, 1} = Data.metadata(table, :cursor)
      assert 5 == Data.last_row(table)
      assert [{{5, 1}, _}, {{5, 2}, _}, {{5, 3}, _}, {{5, 4}, _}] = Data.get_rows(table, 5, 4)
    end
  end
end
