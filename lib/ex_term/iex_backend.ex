defmodule ExTerm.IexBackend do
  @moduledoc false

  alias ExTerm.Backend
  alias Phoenix.PubSub
  import Phoenix.Component

  @behaviour Backend

  @impl Backend
  def on_connect(_params, %{"exterm-backend" => {__MODULE__, opts}}, socket) do
    # TODO: move this to supervising it with a  DynamicSupervisor
    io_server = Keyword.get(opts, :io_server, ExTerm.IexBackend.IOServer)

    {:ok, pid} = DynamicSupervisor.start_child(ExTerm.BackendSupervisor, {io_server, opts})

    pubsub_server = Keyword.fetch!(opts, :pubsub_server)
    pubsub_topic = io_server.pubsub_topic(pid)

    PubSub.subscribe(pubsub_server, pubsub_topic)

    {:ok, io_server.console(pid), assign(socket, io_server: {io_server, pid})}
  end

  @impl Backend
  def on_focus(socket), do: call(socket, :on_focus, [])

  @impl Backend
  def on_blur(socket), do: call(socket, :on_blur, [])

  @impl Backend
  def on_keydown(key, socket), do: call(socket, :on_keydown, [key])

  @impl Backend
  def on_keyup(key, socket), do: call(socket, :on_keyup, [key])

  @impl Backend
  def on_paste(string, socket), do: call(socket, :on_paste, [string])

  @impl Backend
  def on_event(type, payload, socket), do: call(socket, :on_event, [type, payload])

  defp call(socket = %{assigns: %{io_server: {io_server, pid}}}, what, args) do
    apply(io_server, what, [pid | args])
    {:noreply, socket}
  end
end
