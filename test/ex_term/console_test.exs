defmodule ExTermTest.ConsoleTest do
  use ExUnit.Case, async: true

  alias ExTerm.Console
  alias ExTerm.Console.Helpers
  alias ExTerm.Style

  require Helpers

  describe "when you make a console" do
    test "it produces an 24x80 layout by default" do
      console = Console.new()

      Helpers.transaction console, :access do
        assert {24, 80} == Console.layout(console)
        assert {1, 1} == Console.cursor(console)
        assert %Style{} == Console.style(console)

        for row <- 1..24, column <- 1..80 do
          assert %{char: nil} = Console.get(console, {row, column})
        end

        for row <- 1..24, do: assert(is_nil(Console.get(console, {row, 81})))
        assert is_nil(Console.get(console, {25, 1}))
      end
    end

    test "you can customize the layout" do
      console = Console.new(layout: {5, 5})

      Helpers.transaction console, :access do
        assert {5, 5} == Console.layout(console)

        for row <- 1..5, column <- 1..5 do
          assert %{char: nil} = Console.get(console, {row, column})
        end

        for row <- 1..5, do: assert(is_nil(Console.get(console, {row, 6})))
        assert is_nil(Console.get(console, {6, 1}))
      end
    end
  end

  describe "console metadata" do
    setup do
      {:ok, console: Console.new()}
    end

    test "nonexistent metadata start out as nil", %{console: console} do
      Helpers.transaction console, :access do
        assert console
               |> Console.get_metadata(:data)
               |> is_nil
      end
    end

    test "you can set and retrieve console metadata with put_metadata/3", %{console: console} do
      Helpers.transaction console, :mutate do
        assert 47 ===
                 console
                 |> Console.put_metadata(:data, 47)
                 |> Console.get_metadata(:data)
      end
    end

    test "you can set and retrieve console metadata with put_metadata/2", %{console: console} do
      Helpers.transaction console, :mutate do
        assert 47 ===
                 console
                 |> Console.put_metadata(data: 47)
                 |> Console.get_metadata(:data)
      end
    end

    test "you can delete console metadata", %{console: console} do
      Helpers.transaction console, :mutate do
        assert console
               |> Console.put_metadata(:data, 47)
               |> Console.delete_metadata(:data)
               |> Console.get_metadata(:data)
               |> is_nil
      end
    end
  end
end
