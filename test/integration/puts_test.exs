defmodule ExTermTest.PutsTest do
  use ExUnit.Case, async: true
  use ExTermWeb.ConnCase

  alias ExTerm.Style
  alias ExTermTest.FlokiTools
  alias ExTermTest.Console

  import Phoenix.LiveViewTest

  describe "when characters are sent" do
    test "you get back a response and it's sent to the console", %{conn: conn} do
      test_pid = self()

      Mox.expect(ExTermTest.TerminalMock, :run, fn ->
        IO.puts("test")
        Console.sync(test_pid)
        Console.hibernate()
      end)

      {:ok, view, html} = live(conn, "/test")

      Console.unblock()

      doc = render(view)

      assert "test" = FlokiTools.to_text(doc)
      assert {2, 1} = FlokiTools.cursor_location(doc)
    end

#    test "a crlf is split between two lines", %{conn: conn} do
#      {:ok, view, _html} = live(conn, "/")
#
#      puts("test1\ntest2")
#
#      doc = render_parsed(view)
#
#      assert "test1" = FlokiTools.line_to_text(doc, 1)
#      assert "test2" = FlokiTools.line_to_text(doc, 2)
#
#      assert {3, 1} = FlokiTools.cursor_location(doc)
#    end
#
#    test "word wrap on the boundary", %{conn: conn} do
#      long_word = List.duplicate("a", 81)
#
#      {:ok, view, _html} = live(conn, "/")
#
#      puts(long_word)
#
#      Process.sleep(100)
#
#      doc = render_parsed(view)
#
#      assert Enum.join(List.duplicate("a", 80)) == FlokiTools.line_to_text(doc, 1)
#      assert "a" = FlokiTools.line_to_text(doc, 2)
#    end
#
#    test "column wrap when it gets really big", %{conn: conn} do
#      # note that IO.puts will put on a last newline here.
#      long_input =
#        1..24
#        |> Enum.map(&"#{&1}")
#        |> Enum.join("\n")
#
#      {:ok, view, _html} = live(conn, "/")
#
#      puts(long_input)
#
#      doc = render_parsed(view)
#
#      for line <- 2..24, do: assert("#{line}" == FlokiTools.line_to_text(doc, line))
#
#      assert "1" == FlokiTools.buffer_last(doc)
#    end
#  end
#
#  describe "when a ANSI code is sent" do
#    test "it can change the style", %{conn: conn} do
#      {:ok, view, _html} = live(conn, "/")
#
#      puts("abc" <> IO.ANSI.blue() <> "def")
#
#      doc = render_parsed(view)
#
#      "abcdef" = FlokiTools.line_to_text(doc, 1)
#
#      assert %Style{} == FlokiTools.style_at(doc, 1, 1)
#      assert %Style{color: :blue} == FlokiTools.style_at(doc, 1, 4)
#    end
#  end
  end
end
