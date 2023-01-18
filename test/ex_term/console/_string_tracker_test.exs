defmodule ExTermTest.Console.StringTrackerTest do
  use ExUnit.Case, async: true

  alias ExTerm.Console
  alias ExTerm.Console.Cell
  alias ExTerm.Console.Helpers
  alias ExTerm.Console.StringTracker

  require Helpers

  setup do
    console = Console.new(layout: {5, 5})
    {:ok, console: console}
  end

  describe "_blit_string_row/3" do
    test "does nothing when string is empty", %{console: console} do
      # put a first row in.
      Helpers.transaction console, :mutate do
        Console.new_row(console)

        tracker = StringTracker.new(console)

        assert %{
                 cursor: {1, 1},
                 update: %{changes: []},
                 cells: []
               } = StringTracker._blit_string_row(tracker, 5, "")
      end
    end

    test "records updates when it doesn't cross the line", %{console: console} do
      # put a first row in.
      Helpers.transaction console, :mutate do
        Console.new_row(console)

        tracker = StringTracker.new(console)

        assert %{
                 cursor: {1, 4},
                 update: %{changes: [{{1, 1}, {1, 3}}]},
                 cells: [
                   {{1, 3}, %{char: "o"}},
                   {{1, 2}, %{char: "o"}},
                   {{1, 1}, %{char: "f"}}
                 ]
               } = StringTracker._blit_string_row(tracker, 5, "foo")
      end
    end

    test "doesn't try to make changes to the new line when at the end", %{console: console} do
      # put a first row in.
      Helpers.transaction console, :mutate do
        Console.new_row(console)

        tracker = StringTracker.new(console)

        assert {%{
                  cursor: {2, 1},
                  update: %{changes: [{{1, 1}, {1, :end}}]},
                  cells: [
                    {{1, 5}, %{char: "a"}},
                    {{1, 4}, %{char: "b"}},
                    {{1, 3}, %{char: "o"}},
                    {{1, 2}, %{char: "o"}},
                    {{1, 1}, %{char: "f"}}
                  ]
                }, ""} = StringTracker._blit_string_row(tracker, 5, "fooba")

        refute Console.get(console, {2, 1})
      end
    end

    test "releases leftover string", %{console: console} do
      Helpers.transaction console, :mutate do
        Console.new_row(console)

        tracker = StringTracker.new(console)

        assert {%{
                  cursor: {2, 1},
                  update: %{changes: [{{1, 1}, {1, :end}}]},
                  cells: [
                    {{1, 5}, %{char: "a"}},
                    {{1, 4}, %{char: "b"}},
                    {{1, 3}, %{char: "o"}},
                    {{1, 2}, %{char: "o"}},
                    {{1, 1}, %{char: "f"}}
                  ]
                }, "r"} = StringTracker._blit_string_row(tracker, 5, "foobar")

        refute Console.get(console, {2, 1})
      end
    end

    for char <- ["\n", "\r\n", "\r"] do
      test "stops when you do a hard return with #{char}", %{console: console} do
        Helpers.transaction console, :mutate do
          Console.new_row(console)

          tracker = StringTracker.new(console)

          assert {%{
                    cursor: {2, 1},
                    update: %{changes: [{{1, 1}, {1, 3}}]},
                    cells: [
                      {{1, 3}, %{char: "o"}},
                      {{1, 2}, %{char: "o"}},
                      {{1, 1}, %{char: "f"}}
                    ]
                  }, "bar"} = StringTracker._blit_string_row(tracker, 5, "foo#{unquote(char)}bar")

          refute Console.get(console, {2, 1})
        end
      end
    end

    test "will fill out a new line when it's beyond the end", %{console: console} do
      Helpers.transaction console, :mutate do
        tracker = StringTracker.new(console)

        assert {%{
                  cursor: {2, 1},
                  update: %{changes: [{{1, 1}, :end}]},
                  last_cell: {1, 5},
                  cells: [
                    {{1, 3}, %{char: "o"}},
                    {{1, 2}, %{char: "o"}},
                    {{1, 1}, %{char: "f"}}
                  ]
                }, "bar"} = StringTracker._blit_string_row(tracker, 5, "foo\nbar")

        # NOTE that an empty line has been put into the console, but the console won't
        # reflect the string that has been put into it, yet.  You must flush the console
        # to get at those contents.

        for index <- 1..5 do
          assert %{char: nil} = Console.get(console, {1, index})
        end

        assert Cell.sentinel() === Console.get(console, {1, 6})
        refute Console.get(console, {2, 1})
      end
    end

    test "will hard tab from a full stop line", %{console: console} do
      Helpers.transaction console, :mutate do
        tracker =
          console
          |> Console.put_metadata(:layout, {20, 20})
          |> Console.new_row
          |> StringTracker.new()

        assert %{
                  cursor: {1, 10},
                  update: %{cursor: {1, 10}, changes: []},
                  last_cell: {1, 20},
                  cells: []
                } = StringTracker._blit_string_row(tracker, 20, "\t")

        # note that tab has triggered filling out the new row.

        for index <- 1..20 do
          assert %{char: nil} = Console.get(console, {1, index})
        end
        assert Cell.sentinel() == Console.get(console, {1, 21})
      end
    end

    test "will hard tab after adding a character", %{console: console} do
      Helpers.transaction console, :mutate do
        tracker =
          console
          |> Console.put_metadata(:layout, {20, 20})
          |> Console.new_row
          |> StringTracker.new()

        assert %{
                  cursor: {1, 10},
                  update: %{cursor: {1, 10}, changes: [{1, 1}]},
                  last_cell: {1, 20},
                  cells: [{{1, 1}, %{char: "a"}}]
                } = StringTracker._blit_string_row(tracker, 20, "a\t")

        # note that tab has triggered filling out the new row.

        for index <- 1..20 do
          assert %{char: nil} = Console.get(console, {1, index})
        end
        assert Cell.sentinel() == Console.get(console, {1, 21})
      end
    end

    test "will hard tab from a full stop on an empty line", %{console: console} do
      Helpers.transaction console, :mutate do
        tracker =
          console
          |> Console.put_metadata(:layout, {20, 20})
          |> StringTracker.new()

        assert %{
                  cursor: {1, 10},
                  update: %{cursor: {1, 10}, changes: [{{1, 1}, :end}]},
                  last_cell: {1, 20},
                  cells: []
                } = StringTracker._blit_string_row(tracker, 20, "\t")

        # note that tab has triggered filling out the new row.

        for index <- 1..20 do
          assert %{char: nil} = Console.get(console, {1, index})
        end
        assert Cell.sentinel() == Console.get(console, {1, 21})
      end
    end
  end
end
