defmodule ExTermTest.GeometryTest do
  use ExUnit.Case, async: true
  use ExTermWeb.ConnCase

  alias IEx.Server.Relay

  import Phoenix.LiveViewTest

  setup do
    Relay.init()
  end

  def send_geometry_request(what) do
    pid = Relay.pid()
    ref = make_ref()
    send(pid, {:io_request, pid, ref, {:get_geometry, what}})
    ref
  end

  describe "when a geometry request is made" do
    test "you can get the rows", %{conn: conn} do
      {:ok, _view, _html} = live(conn, "/")
      ref = send_geometry_request(:rows)
      assert_receive {:io_reply, ^ref, 40}
    end

    test "you can get the columns", %{conn: conn} do
      {:ok, _view, _html} = live(conn, "/")
      ref = send_geometry_request(:columns)
      assert_receive {:io_reply, ^ref, 80}
    end
  end
end
