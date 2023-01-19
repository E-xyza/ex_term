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

    test "works for a row with a lower length" do
      console = Console.new(handle_update: &updates/1, layout: {5, 5})

      Helpers.transaction console, :mutate do
        Console.new_row(console)
      end

      assert_receive %Update{changes: [{{1, 1}, {1, :end}}]}

      Helpers.transaction console, :access do
        for column <- 1..5 do
          assert %{char: nil} = Console.get(console, {1, column})
        end

        assert %{char: "\n"} = Console.get(console, {1, 6})
        assert nil == Console.get(console, {2, 1})
      end
    end
  end

  describe "new row not at the end" do
    test "fails if the row doesn't exist" do
      console = Console.new(handle_update: &updates/1)

      # note that row 1 doesn't exist
      assert_raise RuntimeError,
                   "attempted to insert row into row 1 but the destination does not exist",
                   fn ->
                     Helpers.transaction console, :mutate do
                       Console.new_row(console, 1)
                     end
                   end
    end

    test "will insert as expected" do
      # 24x80
      console = Console.new(handle_update: &updates/1)

      # SETUP
      cursor =
        Helpers.transaction console, :mutate do
          Console.new_row(console)
          Console.put_cell(console, {1, 1}, %Cell{char: "a"})
          Console.cursor(console)
        end

      assert cursor === {1, 1}
      assert_receive %Update{changes: [{{1, 1}, {1, :end}}]}

      Helpers.transaction console, :mutate do
        Console.new_row(console, 1)
      end

      assert_receive %Update{cursor: {2, 1}, changes: [{{1, 1}, :end}]}

      Helpers.transaction console, :access do
        for column <- 1..80 do
          assert %{char: nil} = Console.get(console, {1, column})
        end

        assert %{char: "\n"} = Console.get(console, {1, 81})
        assert %{char: "a"} = Console.get(console, {2, 1})

        for column <- 2..80 do
          assert %{char: nil} = Console.get(console, {2, column})
        end
      end
    end

    test "will insert the row size of the existing row, not the current dynamic row size" do
      console = Console.new(handle_update: &updates/1, layout: {5, 5})

      # SETUP
      Helpers.transaction console, :mutate do
        Console.new_row(console)
        Console.put_cell(console, {1, 1}, %Cell{char: "a"})
        Console.put_metadata(console, :layout, {8, 8})
        Console.new_row(console)
      end

      assert_receive %Update{changes: [{{1, 1}, {2, :end}}]}

      # verify the structure of the console.

      Helpers.transaction console, :access do
        assert 5 == Console.columns(console, 1)
        assert 8 == Console.columns(console, 2)
      end

      # insert a new row at line 1
      Helpers.transaction console, :mutate do
        Console.new_row(console, 1)
      end

      assert_receive %Update{changes: [{{1, 1}, :end}]}

      Helpers.transaction console, :access do
        assert 5 == Console.columns(console, 1)
        assert 8 == Console.columns(console, 2)
        assert 8 == Console.columns(console, 3)
      end
    end
  end
end
