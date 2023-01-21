defmodule ExTerm.DevApplication do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: ExTerm.PubSub},
      ExTermWeb.Endpoint
    ] ++ ExTerm.Application.children()
    
    opts = [strategy: :one_for_one, name: ExTerm.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ExTermWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
