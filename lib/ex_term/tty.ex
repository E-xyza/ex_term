defmodule ExTerm.Tty do
  @moduledoc false
  @io_server Application.compile_env(:ex_term, :io_server, IEx.Server)

  def start_link(_options) do
    parent = self()

    Task.start_link(fn ->
      :erlang.group_leader(parent, self())
      @io_server.run([])
    end)
  end
end
