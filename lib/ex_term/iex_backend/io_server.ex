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
  alias ExTerm.TerminalSupervisor

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
    pubsub_server = Keyword.fetch!(opts, :pubsub_server)
    pubsub_topic = pubsub_topic(self())
    console = Console.new(handle_update: &broadcast_update(&1, pubsub_server, pubsub_topic))

    {:ok, shell} = TerminalSupervisor.start_child(fn -> IEx.Server.run([]) end)

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

  def on_keydown(server, key), do: GenServer.cast(server, {:on_keydown, key})

  defp on_keydown_impl(key, state = %{prompt: prompt}) do
    case String.next_grapheme(key) do
      {^key, ""} when is_nil(prompt) ->
        {:noreply, %{state | buffer: KeyBuffer.push(state.buffer, key)}}

      {^key, ""} ->
        {:noreply, %{state | prompt: Prompt.push(prompt, key)}}

      _ ->
        special_keydown(key, state)
    end
  end

  defp special_keydown("Enter", state = %{prompt: prompt}) do
    new_state =
      if prompt do
        content =
          prompt.precursor
          |> Enum.reverse(prompt.postcursor)
          |> IO.iodata_to_binary()

        state
        |> Map.update!(:history, &History.commit(&1, content))
        |> Map.update!(:prompt, &Prompt.submit/1)
      else
        %{state | buffer: KeyBuffer.push(state.buffer, "Enter")}
      end

    {:noreply, new_state}
  end

  defp special_keydown("Backspace", state) do
    {:noreply, Map.update!(state, :prompt, &Prompt.backspace/1)}
  end

  defp special_keydown("ArrowLeft", state) do
    {:noreply, Map.update!(state, :prompt, &Prompt.left/1)}
  end

  defp special_keydown("ArrowRight", state) do
    {:noreply, Map.update!(state, :prompt, &Prompt.right/1)}
  end

  defp special_keydown("ArrowUp", state) do
    prompt_content =
      state.prompt
      |> Prompt.content()
      |> String.replace_suffix("\n", "")

    new_state =
      case History.up(state.history, prompt_content) do
        {new_history, new_prompt} ->
          state
          |> Map.replace!(:history, new_history)
          |> Map.update!(:prompt, &Prompt.substitute(&1, new_prompt))

        nil ->
          state
      end

    {:noreply, new_state}
  end

  defp special_keydown("ArrowDown", state) do
    prompt_content =
      state.prompt
      |> Prompt.content()
      |> String.replace_suffix("\n", "")

    new_state =
      case History.down(state.history, prompt_content) do
        {new_history, new_prompt} ->
          state
          |> Map.replace!(:history, new_history)
          |> Map.update!(:prompt, &Prompt.substitute(&1, new_prompt))

        nil ->
          state
      end

    {:noreply, new_state}
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

    {:noreply, %{state | prompt: %{new_prompt | location: {new_row, column}}}}
  end

  @flagkeys ~w(Alt AltGraph CapsLock Control Fn Hyper Meta Shift Super Symbol)

  defp special_keydown(key, state) when key in @flagkeys do
    {:noreply, %{state | flags: MapSet.put(state.flags, key)}}
  end

  defp special_keydown(_, state), do: {:noreply, state}

  def on_keyup(server, key), do: GenServer.cast(server, {:on_keyup, key})

  defp on_keyup_impl(key, state) when key in @flagkeys do
    {:noreply, %{state | flags: MapSet.delete(state.flags, key)}}
  end

  defp on_keyup_impl(_key, state) do
    {:noreply, state}
  end

  def on_paste(server, string), do: GenServer.cast(server, {:on_paste, string})

  defp on_paste_impl(string, state) do
    {:norepply, %{state | prompt: Prompt.paste(state.prompt, string)}}
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
  def handle_cast({:on_keydown, key}, state), do: on_keydown_impl(key, state)
  def handle_cast({:on_keyup, key}, state), do: on_keyup_impl(key, state)
  def handle_cast({:on_paste, string}, state), do: on_paste_impl(string, state)
end