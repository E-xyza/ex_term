defmodule ExTermTest.Console.MoveCursorTest do
  use ExUnit.Case, async: true

  alias ExTerm.Console
  alias ExTerm.Console.Helpers
  alias ExTerm.Console.Update

  require Helpers

  defp updates(info) do
    send(self(), info)
  end

  setup do
    console = Console.new(handle_update: &updates/1)
    {:ok, console: console}
  end

  describe "when you move the cursor" do
    test "to a place that exists, you get an update", %{console: console} do
      Helpers.transaction console, :mutate do
        Console.new_row(console)
      end

      assert_receive %Update{changes: [{{1, 1}, {1, :end}}]}

      Helpers.transaction console, :mutate do
        Console.move_cursor(console, {1, 6})
      end

      assert_receive %Update{cursor: {1, 6}, changes: [{1, 6}, {1, 1}]}
    end

    test "to one after the last line, no update is issued", %{console: console} do
      Helpers.transaction console, :mutate do
        Console.new_row(console)
      end

      assert_receive %Update{changes: [{{1, 1}, {1, :end}}]}

      Helpers.transaction console, :mutate do
        Console.move_cursor(console, {2, 1})
      end

      assert_receive %Update{cursor: {2, 1}, changes: [{2, 1}, {1, 1}]}
    end

    test "to a nonexistent place because the column is too far, it raises", %{console: console} do
      assert_raise RuntimeError,
                   "cursor move to {1, 90} is out of bounds of the console: cursor column 90 is beyond the last column of row 1 (80)",
                   fn ->
                     Helpers.transaction console, :mutate do
                       Console.new_row(console)
                       Console.move_cursor(console, {1, 90})
                     end
                   end
    end

    test "to a nonexistent place because the row is too far, it raises", %{console: console} do
      assert_raise RuntimeError,
                   "cursor move to {3, 4} is out of bounds of the console: cursor row 3 is beyond the last console row (0)",
                   fn ->
                     Helpers.transaction console, :mutate do
                       Console.move_cursor(console, {3, 4})
                     end
                   end
    end
  end
end
