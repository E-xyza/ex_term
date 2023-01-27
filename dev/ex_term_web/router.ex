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

  scope "/" do
    pipe_through :browser

    live_term "/", pubsub: ExTerm.PubSub
  end

  scope "/test" do
    pipe_through :browser

    live_term "/", pubsub: ExTerm.PubSub, terminal: {__MODULE__, :mocked, []}, layout: {5, 5}
  end

  def mocked do
    apply(ExTermTest.TerminalMock, :run, [:erlang.group_leader()])
  end
end
