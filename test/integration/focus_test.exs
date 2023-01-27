defmodule ExTermTest.FocusTest do
  use ExUnit.Case, async: true
  use ExTermWeb.ConnCase

  alias ExTermTest.Console

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    test_pid = self()

    Mox.expect(ExTermTest.TerminalMock, :run, fn _ ->
      Console.sync(test_pid)
      Console.hibernate()
    end)

    {:ok, view, html} = live(conn, "/test")
    {:ok, view: view, html: html}
  end

  test "focus starts as blurred", %{html: html} do
    [classes] =
      html
      |> Floki.parse_document!()
      |> Floki.find("#exterm-terminal")
      |> Floki.attribute("class")

    assert classes =~ "exterm-blurred"
    Console.unblock()
  end

  test "getting focus sets the class to focused", %{view: view} do
    [classes] =
      view
      |> element("#exterm-terminal")
      |> render_focus
      |> Floki.parse_document!()
      |> Floki.find("#exterm-terminal")
      |> Floki.attribute("class")

    assert classes =~ "exterm-focused"
    Console.unblock()
  end

  test "losing focus sets the class to blurred again", %{view: view} do
    view
    |> element("#exterm-terminal")
    |> render_focus

    [classes] =
      view
      |> element("#exterm-terminal")
      |> render_blur
      |> Floki.parse_document!()
      |> Floki.find("#exterm-terminal")
      |> Floki.attribute("class")

    assert classes =~ "exterm-blurred"
    Console.unblock()
  end
end
