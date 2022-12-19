defmodule ExTermTest.FocusTest do
  use ExUnit.Case, async: true
  use ExTermWeb.ConnCase

  alias Plug.Conn

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    Mox.stub_with(IEx.Server.Mock, IEx.Server.Original)
    {:ok, view, html} = live(conn, "/")
    {:ok, view: view, html: html}
  end

  test "focus starts as blurred", %{html: html} do
    [classes] = html
    |> Floki.parse_document!
    |> Floki.find("#exterm-terminal")
    |> Floki.attribute("class")

    assert classes =~ "exterm-blurred"
  end

  test "getting focus sets the class to focused", %{view: view} do
    [classes] = view
    |> element("#exterm-terminal")
    |> render_focus
    |> Floki.parse_document!
    |> Floki.find("#exterm-terminal")
    |> Floki.attribute("class")

    assert classes =~ "exterm-focused"
  end

  test "losing focus sets the class to blurred again", %{view: view} do
    view
    |> element("#exterm-terminal")
    |> render_focus

    [classes] = view
    |> element("#exterm-terminal")
    |> render_blur
    |> Floki.parse_document!
    |> Floki.find("#exterm-terminal")
    |> Floki.attribute("class")

    assert classes =~ "exterm-blurred"
  end
end
