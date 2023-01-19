defmodule ExTermTest.Console.InsertStringTest do
  use ExUnit.Case, async: true

  alias ExTerm.Console
  alias ExTerm.Console.Cell
  alias ExTerm.Console.Helpers
  alias ExTerm.Console.Update

  require Console
  require Helpers

  defp updates(update) do
    send(self(), update)
  end

  setup do
    {:ok, console: Console.new(handle_update: &updates/1, layout: {5, 5})}
  end

  describe "insert_iodata/3" do
    test "works when the string is contained in the row", %{console: console} do
      # note that the cursor starts at {1, 1}
      Helpers.transaction console, :mutate do
        assert {1, 5} ===
                 console
                 |> Console.new_row()
                 |> Console.put_cell({1, 5}, %Cell{char: "a"})
                 |> Console.last_cell()
      end

      assert_receive %Update{changes: [{{1, 1}, {1, :end}}]}

      Helpers.transaction console, :mutate do
        Console.insert_iodata(console, "foo", 1)
      end

      assert_receive %Update{changes: [{{1, 1}, :end}], cursor: {2, 1}}

      Helpers.transaction console, :access do
        assert %{char: "f"} = Console.get(console, {1, 1})
        assert %{char: "o"} = Console.get(console, {1, 2})
        assert %{char: "o"} = Console.get(console, {1, 3})
        assert %{char: nil} = Console.get(console, {1, 4})
        assert %{char: nil} = Console.get(console, {1, 5})
        assert %{char: "a"} = Console.get(console, {2, 5})

        assert {2, 1} = Console.cursor(console)
      end
    end

    test "keeps the cursor the same if it was before", %{console: console} do
      # note that the cursor starts at {1, 1}
      Helpers.transaction console, :mutate do
        assert {2, 5} ===
                 console
                 |> Console.new_row()
                 |> Console.new_row()
                 |> Console.put_cell({2, 5}, %Cell{char: "a"})
                 |> Console.last_cell()
      end

      assert_receive %Update{changes: [{{1, 1}, {2, :end}}]}

      Helpers.transaction console, :mutate do
        Console.insert_iodata(console, "foo", 2)
      end

      assert_receive %Update{changes: [{{2, 1}, :end}], cursor: nil}

      Helpers.transaction console, :access do
        assert %{char: "f"} = Console.get(console, {2, 1})
        assert %{char: "o"} = Console.get(console, {2, 2})
        assert %{char: "o"} = Console.get(console, {2, 3})
        assert %{char: nil} = Console.get(console, {2, 4})
        assert %{char: nil} = Console.get(console, {2, 5})
        assert %{char: "a"} = Console.get(console, {3, 5})

        assert {1, 1} = Console.cursor(console)
      end
    end

    test "works when more than one row is inserted", %{console: console} do
      # note that the cursor starts at {1, 1}
      Helpers.transaction console, :mutate do
        assert {1, 5} ===
                 console
                 |> Console.new_row()
                 |> Console.put_cell({1, 5}, %Cell{char: "a"})
                 |> Console.last_cell()
      end

      assert_receive %Update{changes: [{{1, 1}, {1, :end}}]}

      Helpers.transaction console, :mutate do
        Console.insert_iodata(console, "foobar", 1)
      end

      assert_receive %Update{changes: [{{1, 1}, :end}], cursor: {3, 1}}

      Helpers.transaction console, :access do
        assert %{char: "f"} = Console.get(console, {1, 1})
        assert %{char: "o"} = Console.get(console, {1, 2})
        assert %{char: "o"} = Console.get(console, {1, 3})
        assert %{char: "b"} = Console.get(console, {1, 4})
        assert %{char: "a"} = Console.get(console, {1, 5})
        assert %{char: "r"} = Console.get(console, {2, 1})
        assert %{char: "a"} = Console.get(console, {3, 5})

        assert {3, 1} = Console.cursor(console)
      end
    end
  end
end
