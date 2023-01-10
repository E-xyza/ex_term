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

  describe "put_string" do
    test "works when the string is contained in the row", %{console: console} do
      # note that the cursor starts at {1, 1}
      Helpers.transaction console, :mutate do
        Console.put_string(console, "foo")

        assert_receive Console.update_msg(
                         from: {1, 1},
                         to: {1, 4},
                         cursor: {1, 4},
                         last_cell: {5, 5}
                       )

        assert %{char: "f"} = Console.get(console, {1, 1})
        assert %{char: "o"} = Console.get(console, {1, 2})
        assert %{char: "o"} = Console.get(console, {1, 3})
        assert %{char: nil} = Console.get(console, {1, 4})
      end
    end

    test "works when the string happens to be exactly the correct size of the console", %{
      console: console
    } do
      # note that the cursor starts at {1, 1}
      Helpers.transaction console, :mutate do
        Console.put_string(console, "quuxy")

        assert_receive Console.update_msg(
                         from: {1, 1},
                         to: {2, 1},
                         cursor: {2, 1},
                         last_cell: {5, 5}
                       )

        assert %{char: "q"} = Console.get(console, {1, 1})
        assert %{char: "u"} = Console.get(console, {1, 2})
        assert %{char: "u"} = Console.get(console, {1, 3})
        assert %{char: "x"} = Console.get(console, {1, 4})
        assert %{char: "y"} = Console.get(console, {1, 5})
        assert %{char: nil} = Console.get(console, {2, 1})
      end
    end

    test "works when the string overflows a line", %{console: console} do
      # note that the cursor starts at {1, 1}
      Helpers.transaction console, :mutate do
        Console.put_string(console, "foobar")

        assert_receive Console.update_msg(
                         from: {1, 1},
                         to: {2, 2},
                         cursor: {2, 2},
                         last_cell: {5, 5}
                       )

        assert %{char: "f"} = Console.get(console, {1, 1})
        assert %{char: "o"} = Console.get(console, {1, 2})
        assert %{char: "o"} = Console.get(console, {1, 3})
        assert %{char: "b"} = Console.get(console, {1, 4})
        assert %{char: "a"} = Console.get(console, {1, 5})
        assert %{char: "r"} = Console.get(console, {2, 1})
        assert %{char: nil} = Console.get(console, {2, 2})
      end
    end

    test "puts in a new line when the string overflows the console", %{console: console} do
      Helpers.transaction console, :mutate do
        Console.move_cursor(console, {5, 1})

        Console.put_string(console, "foobar")

        assert_receive Console.update_msg(
                         from: {5, 1},
                         to: {6, 2},
                         cursor: {6, 2},
                         last_cell: {6, 5}
                       )

        assert %{char: "f"} = Console.get(console, {5, 1})
        assert %{char: "o"} = Console.get(console, {5, 2})
        assert %{char: "o"} = Console.get(console, {5, 3})
        assert %{char: "b"} = Console.get(console, {5, 4})
        assert %{char: "a"} = Console.get(console, {5, 5})
        assert %{char: "r"} = Console.get(console, {6, 1})

        for index <- 2..5 do
          assert %{char: nil} = Console.get(console, {6, index})
        end

        assert %{char: "\n"} = Console.get(console, {6, 6})
      end
    end
  end

  describe "put_string with an intervening special actions" do
    test "lf bumps the line", %{console: console} do
      Helpers.transaction console, :mutate do
        Console.put_string(console, "f\noo")

        assert_receive Console.update_msg(
                         from: {1, 1},
                         to: {1, 1},
                         cursor: {2, 1},
                         last_cell: {5, 5}
                       )

        # note that since the cursor moved to this point
        # it's gonna be in the update.
        assert_receive Console.update_msg(
                         from: {2, 1},
                         to: {2, 3},
                         cursor: {2, 3},
                         last_cell: {5, 5}
                       )

        assert %{char: "f"} = Console.get(console, {1, 1})
        assert %{char: "o"} = Console.get(console, {2, 1})
        assert %{char: "o"} = Console.get(console, {2, 2})
      end
    end

    test "crlf bumps the line", %{console: console} do
      Helpers.transaction console, :mutate do
        Console.put_string(console, "f\r\noo")

        assert_receive Console.update_msg(
                         from: {1, 1},
                         to: {1, 1},
                         cursor: {2, 1},
                         last_cell: {5, 5}
                       )

        # note that since the cursor moved to this point
        # it's gonna be in the update.
        assert_receive Console.update_msg(
                         from: {2, 1},
                         to: {2, 3},
                         cursor: {2, 3},
                         last_cell: {5, 5}
                       )

        assert %{char: "f"} = Console.get(console, {1, 1})
        assert %{char: nil} = Console.get(console, {1, 2})
        assert %{char: "o"} = Console.get(console, {2, 1})
        assert %{char: "o"} = Console.get(console, {2, 2})
      end
    end

    test "ANSI code can change the style", %{console: console} do
      Helpers.transaction console, :mutate do
        Console.put_string(console, "f" <> IO.ANSI.red() <> "oo")

        assert_receive Console.update_msg(
                         from: {1, 1},
                         to: {1, 4},
                         cursor: {1, 4},
                         last_cell: {5, 5}
                       )

        assert %{char: "f", style: %{color: nil}} = Console.get(console, {1, 1})
        assert %{char: "o", style: %{color: :red}} = Console.get(console, {1, 2})
        assert %{char: "o", style: %{color: :red}} = Console.get(console, {1, 3})
      end
    end

    test "ANSI code can change the cursor location"
  end
end
