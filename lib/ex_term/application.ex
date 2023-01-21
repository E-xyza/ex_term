defmodule ExTerm.Application do
  @moduledoc false

  use Application

  @impl true

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: ExTerm.Supervisor]
    Supervisor.start_link(children(), opts)
  end

  def children do
    List.wrap(
      if Application.get_env(:ex_term, :supervised, true) do
        [
          ExTerm.TerminalSupervisor,
          {DynamicSupervisor, name: ExTerm.BackendSupervisor},
          {Registry, keys: :unique, name: ExTerm.BackendRegistry}
        ]
      end
    )
  end
end
