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

    test "to one after the last line, no update is issued"

    test "to a nonexistent place, it raises"
  end
end
