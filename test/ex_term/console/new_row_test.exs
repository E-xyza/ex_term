defmodule ExTermTest.Console.NewRowTest do
  use ExUnit.Case, async: true

  alias ExTerm.Console
  alias ExTerm.Console.Helpers

  require Helpers

  defp updates(info) do
    send(self(), {:update, info})
  end

  describe "new_row at the end" do
    test "takes the expected 80 column row" do
      console = Console.new(handle_update: &updates/1) # 24x80
      Helpers.transaction(console, :mutate) do
        Console.new_row(console)
      end

      assert_receive {:update, {{25, 1}, {25, 81}, 80}}

      Helpers.transaction(console, :access) do
        for column <- 1..80 do
          assert %{char: nil} = Console.get(console, {25, column})
        end

        assert %{char: "\n"} = Console.get(console, {25, 81})
        assert nil == Console.get(console, {26, 1})
      end
    end

    test "can return a different row size" do
      console = Console.new(handle_update: &updates/1, layout: {5, 5}) # 24x80
      Helpers.transaction(console, :mutate) do
        Console.new_row(console)
      end

      assert_receive {:update, {{6, 1}, {6, 6}, 5}}

      Helpers.transaction(console, :access) do
        for column <- 1..5 do
          assert %{char: nil} = Console.get(console, {6, column})
        end

        assert %{char: "\n"} = Console.get(console, {6, 6})
        assert nil == Console.get(console, {7, 1})
      end
    end
  end
end
