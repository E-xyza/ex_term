defmodule ExTermTest.Console.InsertStringTest do
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
    {:ok, console: Console.new(handle_update: &updates/1, layout: {5, 5})}
  end

  describe "insert_string/3" do
    test "works when the string is contained in the row", %{console: console} do
      # note that the cursor starts at {1, 1}
      Helpers.transaction console, :mutate do
        Console.put_cell(console, {5, 5}, %Cell{char: "a"})
        # inserts a string on line 4
        Console.insert_string(console, "foo", 5)

        assert_receive Console.update_msg(
                         from: {5, 1},
                         to: {5, 4},
                         cursor: {1, 4},
                         last_cell: {6, 5}
                       )

        assert_receive Console.update_msg(
                         from: {6, 1},
                         to: {6, 6},
                         cursor: {1, 4},
                         last_cell: {6, 5}
                       )

        assert %{char: "f"} = Console.get(console, {5, 1})
        assert %{char: "o"} = Console.get(console, {5, 2})
        assert %{char: "o"} = Console.get(console, {5, 3})
        assert %{char: nil} = Console.get(console, {5, 4})
        assert %{char: nil} = Console.get(console, {5, 5})
        assert %{char: "a"} = Console.get(console, {6, 5})
      end
    end
  end
end
