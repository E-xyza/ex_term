defmodule ExTermTest.Console.PutStringTest do
  use ExUnit.Case, async: true

  alias ExTerm.Console
  alias ExTerm.Console.Cell
  alias ExTerm.Console.Helpers

  require Console
  require Helpers

  defp updates(info) do
    send(self(), {:update, info})
  end

  setup do
    {:ok, console: Console.new(handle_update: &updates/1, layout: {5, 5})}
  end

  describe "put_string" do
    test "works when the string is contained in the row", %{console: console} do
      # note that the cursor starts at {1, 1}
      Helpers.transaction console, :mutate do
        Console.put_string(console, "foo")

        assert_receive Console.update_msg({{1, 1}, {1, 4}, {5, 5}})

        assert %{char: "f"} = Console.get(console, {1, 1})
        assert %{char: "o"} = Console.get(console, {1, 2})
        assert %{char: "o"} = Console.get(console, {1, 3})
        assert %{char: nil} = Console.get(console, {1, 4})
      end

      assert {1, 4} = Console.cursor(console)
    end
  end
end
