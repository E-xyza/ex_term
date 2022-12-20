defmodule ExTermTest.PutsTest do
  use ExUnit.Case, async: true
  use ExTermWeb.ConnCase

  alias ExTerm.Style
  alias ExTermTest.FlokiTools
  alias IEx.Server.Relay

  import Phoenix.LiveViewTest

  setup do
    Relay.init()
  end

  defp puts(content), do: IO.puts(Relay.pid(), content)

  defp render_parsed(view) do
    view
    |> render
    |> Floki.parse_document!()
  end

  describe "when characters are sent" do
    test "you get back a response and it's sent to the console", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      puts("test")

      doc = render_parsed(view)

      assert "test" = FlokiTools.line_to_text(doc, 1)
      assert {2, 1} = FlokiTools.cursor_location(doc)
    end

    test "a crlf is split between two lines", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      puts("test1\ntest2")

      doc = render_parsed(view)

      assert "test1" = FlokiTools.line_to_text(doc, 1)
      assert "test2" = FlokiTools.line_to_text(doc, 2)
      assert {3, 1} = FlokiTools.cursor_location(doc)
    end

    test "word wrap on the boundary", %{conn: conn} do
      long_word = List.duplicate("a", 81)

      {:ok, view, _html} = live(conn, "/")

      puts(long_word)

      doc = render_parsed(view)

      assert Enum.join(List.duplicate("a", 80)) == FlokiTools.line_to_text(doc, 1)
      assert "a" = FlokiTools.line_to_text(doc, 2)
    end

    test "column wrap when it gets really big", %{conn: conn} do
      # note that IO.puts will put on a last newline here.
      long_input = 1..40
      |> Enum.map(&"#{&1}")
      |> Enum.join("\n")

      {:ok, view, _html} = live(conn, "/")

      puts(long_input)

      doc = render_parsed(view)

      for line <- 1..39, do: assert "#{line + 1}" == FlokiTools.line_to_text(doc, line)

      assert "1" == FlokiTools.buffer_last(doc)
    end
  end

  describe "when a ANSI code is sent" do
    test "it can change the style", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      puts("abc" <> IO.ANSI.blue() <> "def")

      doc = render_parsed(view)

      "abcdef" = FlokiTools.line_to_text(doc, 1)

      assert %Style{} == FlokiTools.style_at(doc, {1, 1})
      assert %Style{color: :blue} == FlokiTools.style_at(doc, {1, 4})
    end
  end
end
