defmodule ExTermWeb.PageController do
  use ExTermWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
