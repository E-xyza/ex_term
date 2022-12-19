defmodule ExTermTest.IoTest do
  use ExUnit.Case, async: true
  use ExTermWeb.ConnCase

  alias ExTermTest.Tools
  alias IEx.Server.Relay
  alias Plug.Conn

  import Phoenix.LiveViewTest

  setup do
    Relay.init()
  end

  describe "when characters are sent" do
    test "you get back a response and it's sent to the console", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      relay_pid = Relay.pid()
      IO.puts(relay_pid, "test")

      assert "test" = view
      |> render
      |> Floki.parse_document!
      |> Floki.find("#exterm-row-1")
      |> Tools.floki_line_to_text
    end
  end
end
