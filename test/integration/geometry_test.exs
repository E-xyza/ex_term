defmodule ExTermTest.GeometryTest do
  use ExUnit.Case, async: true
  use ExTermWeb.ConnCase

  alias ExTermTest.Console

  import Phoenix.LiveViewTest

  describe "when a geometry request is made" do
    test "you can get the rows", %{conn: conn} do
      test_pid = self()

      Mox.expect(ExTermTest.TerminalMock, :run, fn _ ->
        Console.sync(test_pid, :io.rows())
        Console.hibernate()
      end)

      {:ok, _view, _html} = live(conn, "/test")

      Console.unblock(fn rows_result ->
        assert {:ok, 5} === rows_result
      end)
    end

    test "you can get the columns", %{conn: conn} do
      test_pid = self()

      Mox.expect(ExTermTest.TerminalMock, :run, fn _ ->
        Console.sync(test_pid, :io.columns())
        Console.hibernate()
      end)

      {:ok, _view, _html} = live(conn, "/test")

      Console.unblock(fn columns_result ->
        assert {:ok, 5} === columns_result
      end)
    end
  end
end
