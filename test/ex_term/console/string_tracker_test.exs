defmodule ExTermTest.Console.StringTrackerTest do
  use ExUnit.Case, async: true

  alias ExTerm.Console
  alias ExTerm.Console.Helpers
  alias ExTerm.Console.StringTracker

  require Helpers

  setup do
    console = Console.new(layout: {5, 5})
    {:ok, console: console}
  end

  describe "_blit_string_row/3" do
    test "correctly does nothing when string is empty", %{console: console} do
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

    test "correctly records updates when it doesn't cross the line", %{console: console} do
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

    test "correctly doesn't try to make changes to the new line when at the end", %{console: console} do
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

    test "correctly releases leftover string", %{console: console} do
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
               }, "r"} = StringTracker._blit_string_row(tracker, 5, "foobar")

        refute Console.get(console, {2, 1})
      end
    end
  end
end
