defmodule ExTermTest.Console.UpdateGetTest do
  use ExUnit.Case, async: true

  alias ExTerm.Console
  alias ExTerm.Console.Helpers
  alias ExTerm.Console.Update

  require Helpers

  setup do
    console = Console.new(layout: {5, 5})

    # lay down a first row of empties
    Helpers.transaction console, :mutate do
      Console.new_row(console)
    end

    {:ok, console: console}
  end

  describe "when get is called with a single" do
    test "location, it is retrieved", %{console: console} do
      Helpers.transaction console, :access do
        assert [{{1, 1}, _}] = Update.get(%Update{changes: [{1, 1}]}, console)
      end
    end

    test "general range, it is retrieved", %{console: console} do
      Helpers.transaction console, :access do
        assert [{{1, 1}, _}, {{1, 2}, _}] =
                 Update.get(%Update{changes: [{{1, 1}, {1, 2}}]}, console)
      end
    end

    test "range that crosses a line, it is retrieved", %{console: console} do
      Helpers.transaction console, :mutate do
        Console.new_row(console)

        assert [
                 {{1, 5}, _},
                 {{1, 6}, _},
                 {{2, 1}, _},
                 {{2, 2}, _}
               ] = Update.get(%Update{changes: [{{1, 5}, {2, 2}}]}, console)
      end
    end

    test "line end range, it is retrieved", %{console: console} do
      Helpers.transaction console, :access do
        assert [
                 {{1, 2}, _},
                 {{1, 3}, _},
                 {{1, 4}, _},
                 {{1, 5}, _},
                 {{1, 6}, _}
               ] = Update.get(%Update{changes: [{{1, 2}, {1, :end}}]}, console)
      end
    end

    test "end range, it is retrieved", %{console: console} do
      Helpers.transaction console, :mutate do
        Console.new_row(console)

        assert [
                 {{1, 5}, _},
                 {{1, 6}, _},
                 {{2, 1}, _},
                 {{2, 2}, _},
                 {{2, 3}, _},
                 {{2, 4}, _},
                 {{2, 5}, _},
                 {{2, 6}, _}
               ] = Update.get(%Update{changes: [{{1, 5}, :end}]}, console)
      end
    end
  end

  describe "when get is called with a a location and a" do
    test "location, it is retrieved", %{console: console} do
      Helpers.transaction console, :access do
        assert [{{1, 1}, _}, {{1, 3}, _}] =
                 Update.get(%Update{changes: [{1, 1}, {1, 3}]}, console)
      end
    end

    test "general range, it is retrieved", %{console: console} do
      Helpers.transaction console, :access do
        assert [{{1, 1}, _}, {{1, 3}, _}, {{1, 4}, _}] =
                 Update.get(%Update{changes: [{1, 1}, {{1, 3}, {1, 4}}]}, console)
      end
    end
  end
end
