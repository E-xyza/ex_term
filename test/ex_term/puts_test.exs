defmodule ExTermTest.PutsTest do
  use ExUnit.Case, async: true
  use ExTermWeb.ConnCase

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
  end
end
