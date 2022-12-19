
defmodule IEx.Server.Relay do
  def init do
    this = self()
    Mox.expect(IEx.Server.Mock, :run, fn _ ->
      send(this, {:relay_pid, self()})
      do_relay(this)
    end)
    :ok
  end

  def pid do
    receive do {:relay_pid, relay} -> relay end
  end

  def fetch(relay_pid) do
    receive do {:relay, ^relay_pid, response} -> response end
  end

  def do_relay(target) do
    receive do
      io_request = {:io_request, _, _, _} ->
        send(:erlang.group_leader(), io_request)
      io_reply = {:io_reply, _, _} ->
        send(target, io_reply)
    end
    do_relay(target)
  end
end
