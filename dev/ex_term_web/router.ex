defmodule ExTermWeb.Router do
  use ExTermWeb, :router
  import ExTerm.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {ExTermWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/" do
    pipe_through :browser

    live_term "/", pubsub_server: ExTerm.PubSub
  end

  scope "/test" do
    pipe_through :browser

    live_term "/", pubsub_server: ExTerm.PubSub, terminal: {ExTermTest.TerminalMock, :run, []}, layout: {5, 5}
  end
end
