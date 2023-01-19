defmodule ExTerm.IexBackend.IOServer do
  @moduledoc false

  # This module is an implementation of the erlang io protocol.  Details of the
  # protocol can be found here:  https://www.erlang.org/doc/apps/stdlib/io_protocol.html
  #
  # This implementation is specifically tuned for use with the ExTerm Console
  # interface.  If you are implementing a different backend for ExTerm, you may
  # want to consider using this code as a guideline.

  alias ExTerm.IOServer

  use IOServer

  alias ExTerm.Console
  alias ExTerm.Console.Helpers
  alias ExTerm.IexBackend.History
  alias ExTerm.IexBackend.KeyBuffer
  alias ExTerm.IexBackend.Prompt

  require Helpers

  alias Phoenix.PubSub

  @enforce_keys [:console, :pubsub_server, :pubsub_topic, :shell]
  defstruct @enforce_keys ++
              [:prompt, buffer: KeyBuffer.new(), history: History.new(), flags: MapSet.new()]

  @type state :: %__MODULE__{
          console: Console.t(),
          pubsub_server: module(),
          pubsub_topic: String.t(),
          shell: pid,
          prompt: nil | GenServer.reply(),
          buffer: KeyBuffer.t(),
          history: History.t(),
          flags: MapSet.t(String.t())
        }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    backend = self()
    opts |> dbg(limit: 25)

    # TODO: move this to tasksupervisor

    {:ok, shell} =
      Task.start_link(fn ->
        :erlang.group_leader(backend, self())
        IEx.Server.run([])
      end)

    pubsub_server = Keyword.fetch!(opts, :pubsub_server)
    pubsub_topic = pubsub_topic(self())
    console = Console.new(handle_update: &broadcast_update(&1, pubsub_server, pubsub_topic))

    {:ok,
     %__MODULE__{
       console: console,
       pubsub_server: pubsub_server,
       pubsub_topic: pubsub_topic,
       shell: shell
     }}
  end

  @impl IOServer
  def handle_geometry(dimension, _from, state = %{console: console}) do
    Helpers.transaction console, :access do
      reply =
        case Console.layout(state.console) do
          {rows, _} when dimension === :rows -> rows
          {_, columns} when dimension === :columns -> columns
        end

      {:ok, reply, state}
    end
  end

  @impl IOServer
  def handle_get(:unicode, prompt, :line, from, state = %{console: console}) do
    cursor =
      Helpers.transaction console, :mutate do
        Console.put_iodata(console, prompt)
        Console.cursor(console)
      end

    case KeyBuffer.pop(state.buffer) do
      {:full, item, new_buffer} ->
        from
        |> Prompt.new(cursor, item, console)
        |> Prompt.submit()

        {:noreply, %{state | prompt: nil, buffer: new_buffer}}

      {:partial, partial, new_buffer} ->
        broadcast_update({:prompt, :active}, state.pubsub_server, state.pubsub_topic)

        {:noreply,
         %{state | prompt: Prompt.new(from, cursor, partial, console), buffer: new_buffer}}
    end
  end

  def handle_get(:latin1, _, _, _, _state) do
    {:error, "latin1 encoding not supported"}
  end

  @impl IOServer
  def handle_put(:unicode, iodata, _from, state = %{console: console}) do
    new_state =
      Helpers.transaction console, :mutate do
        if prompt = state.prompt do
          {row, _} = prompt.location
          range = Console.insert_iodata(console, iodata, row)
          %{state | prompt: Prompt.bump_prompt(prompt, range)}
        else
          Console.put_iodata(console, iodata)
          state
        end
      end

    {:ok, new_state}
  end

  def handle_put(:latin1, _, _, _state) do
    {:error, "latin1 encoding not supported"}
  end

  @impl IOServer
  def handle_setopts(_, _, _state) do
    {:error, :not_implemented}
  end

  @impl IOServer
  def handle_getopts(_, _, _state) do
    {:error, :not_implemented}
  end

  #############################################################################
  # LiveView callback implementations

  # following events are ignored.
  def on_focus(_server), do: :ok
  def on_blur(_server), do: :ok
  def on_event(_server, _type, _payload), do: :ok

  def on_keydown(server, key), do: GenServer.call(server, {:on_keydown, key})

  defp on_keydown_impl(key, _from, state = %{prompt: prompt}) do
    case String.next_grapheme(key) do
      {^key, ""} when is_nil(prompt) ->
        {:reply, :ok, %{state | buffer: KeyBuffer.push(state.buffer, key)}}

      {^key, ""} ->
        {:reply, :ok, %{state | prompt: Prompt.push(prompt, key)}}

      _ ->
        special_keydown(key, state)
    end
  end

  defp special_keydown("Enter", state) do
    new_state =
      if state.prompt do
        state
        |> History.commit()
        |> Map.update!(:prompt, &Prompt.submit/1)
      else
        %{state | buffer: KeyBuffer.push(state.buffer, "Enter")}
      end

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

  defp special_keydown(
         "Tab",
         state = %{console: console, prompt: prompt = %{location: {row, column}}}
       ) do
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
            {init_row, _} = Console.cursor(console)

            {end_row, _} =
              console
              |> Console.insert_iodata(options, row)
              |> Console.get_metadata(:cursor)

            # rows added
            {prompt, row + end_row - init_row}
          end

        {:yes, one_option, []} ->
          new_prompt = Prompt.append(prompt, one_option)

          {row, _} =
            Helpers.transaction console, :access do
              Console.cursor(console)
            end

          {new_prompt, row}
      end

    {:reply, :ok, %{state | prompt: %{new_prompt | location: {new_row, column}}}}
  end

  @flagkeys ~w(Alt AltGraph CapsLock Control Fn Hyper Meta Shift Super Symbol)

  defp special_keydown(key, state) when key in @flagkeys do
    {:reply, :ok, %{state | flags: MapSet.put(state.flags, key)}}
  end

  defp special_keydown(_, state), do: {:reply, :ok, state}

  def on_keyup(server, key), do: GenServer.call(server, {:on_keyup, key})

  defp on_keyup_impl(key, _from, state) when key in @flagkeys do
    {:reply, :ok, %{state | flags: MapSet.delete(state.flags, key)}}
  end

  defp on_keyup_impl(_key, _from, state) do
    {:reply, :ok, state}
  end

  def on_paste(server, string), do: GenServer.call(server, {:on_paste, string})

  defp on_paste_impl(string, _from, state) do
    {:reply, :ok, %{state | prompt: Prompt.paste(state.prompt, string)}}
  end

  ### UTILITIES
  def console(server), do: GenServer.call(server, :console)

  defp console_impl(_from, state), do: {:reply, state.console, state}

  def pubsub_topic(pid) do
    :sha256
    |> :crypto.hash(:erlang.term_to_binary(pid))
    |> Base.encode64()
    |> String.replace_prefix("", "exterm:iex-backend:")
  end

  defp broadcast_update(update, pubsub_server, pubsub_topic) do
    PubSub.broadcast(pubsub_server, pubsub_topic, update)
  end

  # GENSERVER ROUTER
  @impl GenServer
  def handle_call(:console, from, state), do: console_impl(from, state)
  def handle_call({:on_keydown, key}, from, state), do: on_keydown_impl(key, from, state)
  def handle_call({:on_keyup, key}, from, state), do: on_keyup_impl(key, from, state)
  def handle_call({:on_paste, string}, from, state), do: on_paste_impl(string, from, state)
end
