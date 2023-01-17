defmodule ExTermTest.Console.NewRowTest do
  use ExUnit.Case, async: true

  alias ExTerm.Console
  alias ExTerm.Console.Cell
  alias ExTerm.Console.Helpers
  alias ExTerm.Console.Update

  require Console
  require Helpers

  defp updates(info) do
    send(self(), info)
  end

  describe "new_row at the end" do
    test "creates the expected default 80 column row" do
      console = Console.new(handle_update: &updates/1)

      Helpers.transaction console, :mutate do
        Console.new_row(console)
      end

      assert_receive %Update{changes: [{{1, 1}, {1, :end}}]}

      Helpers.transaction console, :access do
        for column <- 1..80 do
          assert %{char: nil} = Console.get(console, {1, column})
        end

        assert %{char: "\n"} = Console.get(console, {1, 81})
        assert nil == Console.get(console, {2, 1})
      end
    end

#    test "works for a row with a lower length" do
#      # 24x80
#      console = Console.new(handle_update: &updates/1, layout: {5, 5})
#
#      Helpers.transaction console, :mutate do
#        Console.new_row(console)
#      end
#
#      assert_receive Console.update_msg({{6, 1}, {6, 6}, {6, 5}})
#
#      Helpers.transaction console, :access do
#        for column <- 1..5 do
#          assert %{char: nil} = Console.get(console, {6, column})
#        end
#
#        assert %{char: "\n"} = Console.get(console, {6, 6})
#        assert nil == Console.get(console, {7, 1})
#      end
#    end
#  end
#
#  describe "new row not at the end" do
#    test "will insert as expected" do
#      # 24x80
#      console = Console.new(handle_update: &updates/1)
#
#      Helpers.transaction console, :mutate do
#        Console.put_cell(console, {5, 1}, %Cell{char: "a"})
#        Console.new_row(console, 5)
#      end
#
#      assert_receive Console.update_msg({{5, 1}, {25, 81}, {25, 80}})
#
#      Helpers.transaction console, :access do
#        for column <- 1..80 do
#          assert %{char: nil} = Console.get(console, {5, column})
#        end
#
#        assert %{char: "\n"} = Console.get(console, {5, 81})
#        assert %{char: "a"} = Console.get(console, {6, 1})
#
#        for column <- 2..80 do
#          assert %{char: nil} = Console.get(console, {6, column})
#        end
#
#        for column <- 1..80 do
#          assert %{char: nil} = Console.get(console, {25, column})
#        end
#
#        assert nil == Console.get(console, {26, 1})
#      end
#    end
#
#    test "will insert the row size of the existing row, not the dynamic row" do
#      # 24x80
#      console = Console.new(handle_update: &updates/1, layout: {5, 5})
#
#      Helpers.transaction console, :mutate do
#        # adjust the layout to have much bigger dimensions
#        Console.put_metadata(console, {8, 8})
#        Console.put_cell(console, {5, 1}, %Cell{char: "a"})
#        Console.new_row(console, 5)
#      end
#
#      assert_receive Console.update_msg({{5, 1}, {6, 6}, {6, 5}})
#
#      Helpers.transaction console, :access do
#        for column <- 1..5 do
#          assert %{char: nil} = Console.get(console, {5, column})
#        end
#
#        assert %{char: "\n"} = Console.get(console, {5, 6})
#        assert %{char: "a"} = Console.get(console, {6, 1})
#        assert nil == Console.get(console, {7, 1})
#      end
#    end
  end
end
