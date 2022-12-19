defmodule ExTerm.Tty do
  def start_link do
    parent = self()

    Task.start_link(fn ->
      :erlang.group_leader(parent, self())
      IEx.Server.run([])
    end)
  end
end
