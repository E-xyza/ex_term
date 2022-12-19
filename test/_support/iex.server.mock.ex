defmodule IoServer do
  @callback run(keyword) :: no_return
end

defmodule IEx.Server.Original do
  @behaviour IoServer

  @impl IoServer
  defdelegate run(opts), to: IEx.Server
end

Mox.defmock(IEx.Server.Mock, for: IoServer)
