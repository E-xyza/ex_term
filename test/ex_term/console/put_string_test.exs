defmodule ExTermTest.Console.PutStringTest do
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

  describe "put_string/2" do
    test "works when nothing exists in the row and string is contained", %{console: console} do
      # note that the cursor starts at {1, 1}
      Helpers.transaction console, :mutate do
        Console.put_string(console, "foo")
      end

      assert_receive %{cursor: {1, 4}, changes: [{{1, 1}, {1, :end}}]}

      Helpers.transaction console, :access do
        assert %{char: "f"} = Console.get(console, {1, 1})
        assert %{char: "o"} = Console.get(console, {1, 2})
        assert %{char: "o"} = Console.get(console, {1, 3})
        assert %{char: nil} = Console.get(console, {1, 4})
        assert %{char: nil} = Console.get(console, {1, 5})
        assert %{char: "\n"} = Console.get(console, {1, 6})
      end
    end

    test "works when the row exists", %{console: console} do
      # note that the cursor starts at {1, 1}
      Helpers.transaction console, :mutate do
        Console.new_row(console)
      end

      Helpers.transaction console, :mutate do
        Console.put_string(console, "foo")
      end

      assert_receive %{cursor: {1, 4}, changes: [{{1, 1}, {1, 4}}]}

      Helpers.transaction console, :access do
        assert %{char: "f"} = Console.get(console, {1, 1})
        assert %{char: "o"} = Console.get(console, {1, 2})
        assert %{char: "o"} = Console.get(console, {1, 3})
        assert %{char: nil} = Console.get(console, {1, 4})
        assert %{char: nil} = Console.get(console, {1, 5})
        assert %{char: "\n"} = Console.get(console, {1, 6})
      end
    end

    test "works when nothing exists in the row and string is exactly the correct length", %{
      console: console
    } do
      # note that the cursor starts at {1, 1}
      Helpers.transaction console, :mutate do
        Console.put_string(console, "fooba")
      end

      assert_receive %{cursor: {2, 1}, changes: [{{1, 1}, {1, :end}}]}

      Helpers.transaction console, :access do
        assert %{char: "f"} = Console.get(console, {1, 1})
        assert %{char: "o"} = Console.get(console, {1, 2})
        assert %{char: "o"} = Console.get(console, {1, 3})
        assert %{char: "b"} = Console.get(console, {1, 4})
        assert %{char: "a"} = Console.get(console, {1, 5})
        assert %{char: "\n"} = Console.get(console, {1, 6})

        refute Console.get(console, {2, 1})
      end
    end

    test "works when nothing exists in the row and string overflows", %{console: console} do
      # note that the cursor starts at {1, 1}
      Helpers.transaction console, :mutate do
        Console.put_string(console, "foobar")
      end

      assert_receive %{cursor: {2, 2}, changes: [{{1, 1}, {2, :end}}]}

      Helpers.transaction console, :access do
        assert %{char: "f"} = Console.get(console, {1, 1})
        assert %{char: "o"} = Console.get(console, {1, 2})
        assert %{char: "o"} = Console.get(console, {1, 3})
        assert %{char: "b"} = Console.get(console, {1, 4})
        assert %{char: "a"} = Console.get(console, {1, 5})
        assert %{char: "\n"} = Console.get(console, {1, 6})
        assert %{char: "r"} = Console.get(console, {2, 1})
        assert %{char: nil} = Console.get(console, {2, 5})
        assert %{char: "\n"} = Console.get(console, {2, 6})
        refute Console.get(console, {3, 1})
      end
    end

    for return <- ["\n", "\r", "\r\n"] do
      test "works when hard return (#{return}) causes string overflow", %{console: console} do
        # note that the cursor starts at {1, 1}
        Helpers.transaction console, :mutate do
          Console.put_string(console, "foo#{unquote(return)}bar")
        end

        assert_receive %{cursor: {2, 4}, changes: [{{1, 1}, {2, :end}}]}

        Helpers.transaction console, :access do
          assert %{char: "f"} = Console.get(console, {1, 1})
          assert %{char: "o"} = Console.get(console, {1, 2})
          assert %{char: "o"} = Console.get(console, {1, 3})
          assert %{char: nil} = Console.get(console, {1, 4})
          assert %{char: nil} = Console.get(console, {1, 5})
          assert %{char: "\n"} = Console.get(console, {1, 6})
          assert %{char: "b"} = Console.get(console, {2, 1})
          assert %{char: "a"} = Console.get(console, {2, 2})
          assert %{char: "r"} = Console.get(console, {2, 3})
          assert %{char: nil} = Console.get(console, {2, 5})
          assert %{char: "\n"} = Console.get(console, {2, 6})
          refute Console.get(console, {3, 1})
        end
      end
    end

    test "ANSI code can change the style", %{console: console} do
      Helpers.transaction console, :mutate do
        Console.put_string(console, "f" <> IO.ANSI.red() <> "oo")
      end

      assert_receive %{cursor: {1, 4}, changes: [{{1, 1}, {1, :end}}]}

      Helpers.transaction console, :access do
        assert %{char: "f", style: %{color: nil}} = Console.get(console, {1, 1})
        assert %{char: "o", style: %{color: :red}} = Console.get(console, {1, 2})
        assert %{char: "o", style: %{color: :red}} = Console.get(console, {1, 3})
      end
    end

    test "ANSI code can change the cursor location"
  end
end
