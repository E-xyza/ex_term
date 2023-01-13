defmodule ExTerm.IexBackend do
  @moduledoc false

  alias ExTerm.Backend
  alias ExTerm.Console
  alias ExTerm.Console.Helpers
  alias ExTerm.IexBackend.History
  alias ExTerm.IexBackend.Prompt
  alias Phoenix.PubSub

  require Helpers

  @behaviour Backend
  use GenServer

  @enforce_keys [:console, :pubsub_topic, :shell]
  defstruct @enforce_keys ++ [:prompt, history: History.new(), flags: MapSet.new()]

  @type state :: %__MODULE__{
          console: Console.t(),
          pubsub_topic: String.t(),
          shell: pid,
          prompt: nil | GenServer.reply(),
          history: History.t,
          flags: MapSet.t(String.t())
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

    {:ok, shell} =
      Task.start_link(fn ->
        :erlang.group_leader(backend, self())
        IEx.Server.run([])
      end)

    pubsub_topic = pubsub_topic(backend)

    console = Console.new(handle_update: &broadcast_update(&1, @pubsub_server, pubsub_topic))

    {:ok, %__MODULE__{console: console, pubsub_topic: pubsub_topic, shell: shell}}
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

    ExTerm.io_reply(from, {:ok, reply})
  end

  @impl Backend
  def handle_focus(_), do: {:ok, focus: true}

  @impl Backend
  def handle_blur(_), do: {:ok, focus: false}

  ## ROUTER: HANDLE_IO
  def handle_io_request(from, {:put_chars, :unicode, str}, state = %{console: console}) do
    if state.prompt do
      raise "not yet"
    else
      Helpers.transaction console, :mutate do
        Console.put_string(console, str)
      end

      ExTerm.io_reply(from)
      {:noreply, state}
    end
  end

  def handle_io_request(from, {:get_line, :unicode, prompt}, state = %{console: console}) do
    cursor =
      Helpers.transaction console, :mutate do
        Console.put_string(console, prompt)
        Console.get_metadata(console, :cursor)
      end

    broadcast_update({:prompt, :active}, @pubsub_server, state.pubsub_topic)
    {:noreply, %{state | prompt: Prompt.new(from, cursor, console)}}
  end

  def handle_io_request(from, {:get_geometry, type}, state) do
    get_geometry_impl(from, type, state)
    {:noreply, state}
  end

  @impl Backend
  def handle_update(_, console, from, to, cursor, _) do
    Helpers.transaction console, :access do
      {:ok, cells: Console.cells(console, from, to), cursor: cursor}
    end
  end

  @impl Backend
  def handle_keydown(pid, key), do: GenServer.call(pid, {:handle_keydown, key})

  defp handle_keydown_impl(key, _from, state) do
    case String.next_grapheme(key) do
      {^key, ""} ->
        {:reply, :ok, %{state | prompt: Prompt.push(state.prompt, key)}}

      _ ->
        special_keydown(key, state)
    end
  end

  defp special_keydown("Enter", state) do
    new_state = state
    |> History.commit()
    |> Map.update!(:prompt, &Prompt.submit/1)

    {:reply, :ok, new_state}
  end

  defp special_keydown("Backspace", state) do
    {:reply, :ok, %{state | prompt: Prompt.backspace(state.prompt)}}
  end

  defp special_keydown("ArrowLeft", state) do
    {:reply, :ok, %{state | prompt: Prompt.left(state.prompt)}}
  end

  defp special_keydown("ArrowRight", state) do
    {:reply, :ok, %{state | prompt: Prompt.right(state.prompt)}}
  end

  defp special_keydown("ArrowUp", state) do
    {:reply, :ok, History.up(state)}
  end

  defp special_keydown("ArrowDown", state) do
    {:reply, :ok, History.down(state)}
  end

  defp special_keydown("Tab", state = %{console: console, prompt: prompt = %{location: {row, column}}}) do
    {new_prompt, new_row} =
      prompt.precursor
      |> Enum.flat_map(&String.to_charlist/1)
      |> IEx.Autocomplete.expand()
      |> case do
        {:no, _, _} ->
          {prompt, row}

        {:yes, [], list_of_options} ->
          options = Enum.join(list_of_options, "\t")

          Helpers.transaction console, :mutate do
            {init_row, _} = Console.get_metadata(console, :cursor)

            {end_row, _} =
              console
              |> Console.insert_string(options, row)
              |> Console.get_metadata(:cursor)

            # rows added
            {prompt, row + end_row - init_row}
          end

        {:yes, one_option, []} ->
          new_prompt = Prompt.substitute(prompt, one_option)
          {row, _} = Helpers.transaction console, :access do
            Console.get_metadata(console, :cursor)
          end
          {new_prompt, row}
      end

    {:reply, :ok, %{state | prompt: %{new_prompt | location: {new_row, column}}}}
  end

  @flagkeys ~w(Alt AltGraph CapsLock Control Fn Hyper Meta Shift Super Symbol)

  defp special_keydown(key, state) when key in @flagkeys do
    {:reply, :ok, %{state | flags: MapSet.put(state.flags, key)}}
  end

  defp special_keydown(other, _state) do
    raise "#{other} not supported yet"
  end

  @impl Backend
  def handle_paste(pid, paste), do: GenServer.call(pid, {:handle_paste, paste})

  defp handle_paste_impl(paste, _from, state) do
    {:reply, :ok, %{state | prompt: Prompt.paste(state.prompt, paste)}}
  end

  @impl GenServer
  def handle_info({:io_request, pid, ref, request}, state) do
    handle_io_request({pid, ref}, request, state)
  end

  ### ROUTER
  @impl GenServer
  def handle_call(:get_console, from, state), do: get_console_impl(from, state)
  def handle_call({:handle_keydown, key}, from, state), do: handle_keydown_impl(key, from, state)
  def handle_call({:handle_paste, paste}, from, state), do: handle_paste_impl(paste, from, state)

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