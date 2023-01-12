defmodule ExTerm.IexBackend do
  @moduledoc false

  alias ExTerm.Backend
  alias ExTerm.Console
  alias ExTerm.Console.Helpers
  alias Phoenix.PubSub

  require Helpers

  @behaviour Backend
  use GenServer

  @enforce_keys [:console, :pubsub_topic]
  defstruct @enforce_keys ++ [prompting?: false]

  @type state :: %__MODULE__{
          console: Console.t(),
          prompting?: boolean,
          pubsub_topic: String.t()
        }

  @pubsub_server ExTerm.PubSub

  # ENTRYPOINT AND BOILERPLATE

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  @impl GenServer
  def init(_) do
    # TODO: move this to a DynamicSupervisor.
    backend = self()

    Task.start_link(fn ->
      :erlang.group_leader(backend, self())
      IEx.Server.run([])
    end)

    pubsub_topic = pubsub_topic(backend)

    console = Console.new(handle_update: &broadcast_update(&1, @pubsub_server, pubsub_topic))

    {:ok, %__MODULE__{console: console, pubsub_topic: pubsub_topic}}
  end

  @impl Backend
  def mount(_, _, _) do
    # TODO: move this to supervising it with a  DynamicSupervisor
    {:ok, pid} = start_link([])

    # TODO: make the pubsub configurable
    pubsub_topic = pubsub_topic(pid)
    PubSub.subscribe(ExTerm.PubSub, pubsub_topic)

    {:ok, pid, get_console(pid)}
  end

  # API

  @spec get_console(GenServer.server()) :: Console.t()

  # API IMPLEMENTATIONS

  def get_console(server), do: GenServer.call(server, :get_console)

  defp get_console_impl(from, state), do: {:reply, state.console, state}

  defp get_geometry_impl(from, dimension, state) do
    reply =
      case Console.layout(state.console) do
        {rows, _} when dimension === :rows -> rows
        {_, columns} when dimension === :columns -> columns
      end

    ExTerm.io_reply(from, reply)
  end

  @impl Backend
  def handle_focus(_), do: {:ok, focus: true}

  @impl Backend
  def handle_blur(_), do: {:ok, focus: false}

  ## ROUTER: HANDLE_IO
  def handle_io_request(from, {:put_chars, :unicode, str}, state = %{console: console}) do
    if state.prompting? do
      raise "not yet"
    else
      Helpers.transaction console, :mutate do
        Console.put_string(console, str)
      end
    end

    ExTerm.io_reply(from)
    {:noreply, %{state | prompting?: true}}
  end

  def handle_io_request(from, {:get_line, :unicode, prompt}, state = %{console: console}) do
    Helpers.transaction console, :mutate do
      Console.put_string(console, prompt)
    end

    broadcast_update({:prompt, :active}, @pubsub_server, state.pubsub_topic)
    {:noreply, %{state | prompting?: true}}
  end

  def handle_io_request(from, {:get_geometry, type}, state) do
    get_geometry_impl(from, type, state)
  end

  @impl Backend
  def handle_update(_, console, from, to, cursor, _) do
    Helpers.transaction(console, :access) do
      {:ok, cells: Console.cells(console, from, to), cursor: cursor}
    end
  end

  @impl GenServer
  def handle_info({:io_request, pid, ref, request}, state) do
    handle_io_request({pid, ref}, request, state)
  end

  ### ROUTER
  @impl GenServer
  def handle_call(:get_console, from, state), do: get_console_impl(from, state)

  ### UTILITIES
  defp pubsub_topic(pid) do
    :sha256
    |> :crypto.hash(:erlang.term_to_binary(pid))
    |> Base.encode64()
    |> String.replace_prefix("", "exterm:iex-backend:")
  end

  defp broadcast_update(update, pubsub_server, pubsub_topic) do
    PubSub.broadcast(pubsub_server, pubsub_topic, update)
  end
end
