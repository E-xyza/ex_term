defmodule ExTermTest.PutsTest do
  use ExUnit.Case, async: true
  use ExTermWeb.ConnCase

  alias ExTerm.Style
  alias ExTermTest.FlokiTools
  alias ExTermTest.Console

  import Phoenix.LiveViewTest

  describe "when characters are sent" do
    defp send_content_test(conn, content) do
      test_pid = self()

      Mox.expect(ExTermTest.TerminalMock, :run, fn ->
        IO.puts(content)
        Console.sync(test_pid)
        Console.hibernate()
      end)

      {:ok, view, _html} = live(conn, "/test")

      Console.unblock()

      doc = render(view)

      text = FlokiTools.to_text(doc)

      cursor = FlokiTools.cursor_location(doc)
      {text, cursor}
    end

    test "you get back a response and it's sent to the console", %{conn: conn} do
      assert {"test", {2, 1}} = send_content_test(conn, "test")
    end

    test "a crlf is split between two lines", %{conn: conn} do
      assert {"test\ntest", {3, 1}} = send_content_test(conn, "test\ntest")
    end

    test "word wrap on the boundary", %{conn: conn} do
      assert {"longw\nord", {3, 1}} = send_content_test(conn, "longword")
    end
  end

  describe "when a ANSI code is sent" do
    test "it can change the style", %{conn: conn} do
      test_pid = self()

      Mox.expect(ExTermTest.TerminalMock, :run, fn ->
        IO.puts("abc" <> IO.ANSI.blue() <> "def")
        Console.sync(test_pid)
        Console.hibernate()
      end)

      {:ok, view, _html} = live(conn, "/test")

      Console.unblock()

      doc = render(view)

      assert "abcde\nf" = FlokiTools.to_text(doc)
      assert %Style{} == FlokiTools.style_at(doc, 1, 1)
      assert %Style{color: :blue} == FlokiTools.style_at(doc, 1, 4)
    end
  end

end
