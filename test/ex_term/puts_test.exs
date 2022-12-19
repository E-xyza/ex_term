defmodule ExTermTest.PutsTest do
  use ExUnit.Case, async: true
  use ExTermWeb.ConnCase

  alias ExTermTest.FlokiTools
  alias IEx.Server.Relay

  import Phoenix.LiveViewTest

  setup do
    Relay.init()
  end

  describe "when characters are sent" do
    test "you get back a response and it's sent to the console", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      relay_pid = Relay.pid()
      IO.puts(relay_pid, "test")

      doc =
        view
        |> render
        |> Floki.parse_document!()

      assert "test" = FlokiTools.line_to_text(doc, 1)
      assert {2, 1} = FlokiTools.cursor_location(doc)
    end

    test "a crlf is split between two lines", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      relay_pid = Relay.pid()
      IO.puts(relay_pid, "test1\ntest2")

      doc =
        view
        |> render
        |> Floki.parse_document!()

      assert "test1" = FlokiTools.line_to_text(doc, 1)
      assert "test2" = FlokiTools.line_to_text(doc, 2)
      assert {3, 1} = FlokiTools.cursor_location(doc)
    end
  end
end
