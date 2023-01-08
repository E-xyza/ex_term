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

        assert_receive Console.update_msg({{1, 1}, {1, 3}, {5, 5}})

        assert %{char: "f"} = Console.get(console, {1, 1})
        assert %{char: "o"} = Console.get(console, {1, 2})
        assert %{char: "o"} = Console.get(console, {1, 3})
        assert %{char: nil} = Console.get(console, {1, 4})
      end

      assert {1, 4} = Console.cursor(console)
    end

    test "works when the string happens to be exactly the correct size of the console", %{console: console} do
      # note that the cursor starts at {1, 1}
      Helpers.transaction console, :mutate do
        Console.put_string(console, "quuxy")

        assert_receive Console.update_msg({{1, 1}, {1, 5}, {5, 5}})

        assert %{char: "q"} = Console.get(console, {1, 1})
        assert %{char: "u"} = Console.get(console, {1, 2})
        assert %{char: "u"} = Console.get(console, {1, 3})
        assert %{char: "x"} = Console.get(console, {1, 4})
        assert %{char: "y"} = Console.get(console, {1, 5})
        assert %{char: nil} = Console.get(console, {2, 1})
      end

      assert {2, 1} = Console.cursor(console)
    end

    test "works when the string overflows a line", %{console: console} do
      # note that the cursor starts at {1, 1}
      Helpers.transaction console, :mutate do
        Console.put_string(console, "foobar")

        assert_receive Console.update_msg({{1, 1}, {2, 1}, {5, 5}})

        assert %{char: "f"} = Console.get(console, {1, 1})
        assert %{char: "o"} = Console.get(console, {1, 2})
        assert %{char: "o"} = Console.get(console, {1, 3})
        assert %{char: "b"} = Console.get(console, {1, 4})
        assert %{char: "a"} = Console.get(console, {1, 5})
        assert %{char: "r"} = Console.get(console, {2, 1})
        assert %{char: nil} = Console.get(console, {2, 2})
      end

      assert {2, 2} = Console.cursor(console)
    end
  end
end
