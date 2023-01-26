defmodule ExTerm.IOServer do
  @moduledoc """
  behaviour template for implementing a server which responds to Robert
  Virding's IO Protocol:

  https://www.erlang.org/doc/apps/stdlib/io_protocol.html

  Note that ExTerm does NOT require you to implement an IOServer; you can also
  implement it as a process-less module attached to the LiveView using the
  backend module itself.
  """

  defmacro __using__(opts) do
    quote do
      use GenServer, unquote(opts)
      @behaviour ExTerm.IOServer

      def handle_info({:io_request, pid, tag, request}, state) do
        ExTerm.IOServer.marshal(__MODULE__, request, {pid, tag}, state, true)
      end

      def handle_info(msg, state) do
        if function_exported?(__MODULE__, :handle_message, 2) do
          apply(__MODULE__, :handle_message, [msg, state])
        else
          IO.warn("unexpected message #{inspect(msg)} received by process #{inspect(self())}")
          {:noreply, state}
        end
      end
    end
  end

  @type encoding :: :latin | :unicode
  @type mfargs :: {module, atom, [term]}
  @type state :: term
  @type get_condition :: {:until, mfargs} | {:chars, non_neg_integer} | :line
  @type from :: GenServer.from()
  @type basic_reply :: :ok | {:error, term}
  @type get_reply :: iodata | :eof | {:error, term}
  @type opt ::
          :binary
          | :list
          | :unicode
          | :latin1
          | {:binary, boolean}
          | {:echo, boolean}
          | {:expand_fun, fun}
          | {:encoding, :unicode | :latin1}
          | {atom, term}
  @type opts :: [opt]
  @type geometry :: :rows | :columns
  @type noreply :: {:noreply, state} | {:noreply, state, timeout | :hibernate | {:continue, term}}
  @type reply(type) ::
          {:reply, type, state} | {:reply, type, state, timeout | :hibernate | {:continue, term}}
  @type stop(type) :: {:stop, reason :: term, type, state}
  @type basic_response ::
          {:ok, state}
          | {:error, reason :: term, state}
          | reply(basic_reply)
          | noreply
          | stop(basic_reply)
  @type response(type) ::
          {:ok, type, state}
          | {:error, reason :: term, state}
          | reply(type)
          | noreply
          | stop(type)

  @callback handle_put(encoding, iodata | mfargs, from, state) :: basic_response()
  @callback handle_get(encoding, prompt :: iodata, get_condition, from, state) ::
              response(get_reply)
  @callback handle_setopts(opts, from, state) :: basic_response()
  @callback handle_getopts(from, state) :: response(keyword)
  @callback handle_geometry(geometry, from, state) :: response(non_neg_integer())
  @callback handle_request(term, from, state) :: response(term)
  @callback handle_message(term, state) :: noreply | {:stop, reason :: term, state}
  @optional_callbacks [handle_request: 3, handle_message: 2]

  def reply({pid, tag}, msg) do
    send(pid, {:io_reply, tag, msg})
  end

  @doc false
  def marshal(module, {:put_chars, encoding, iodata}, from, state, should_send) do
    module
    |> apply(:handle_put, [encoding, iodata, from, state])
    |> to_genserver_info(from, should_send)
  end

  def marshal(module, {:put_chars, encoding, mod, fun, args}, from, state, should_send) do
    module
    |> apply(:handle_put, [encoding, {mod, fun, args}, from, state])
    |> to_genserver_info(from, should_send)
  end

  def marshal(module, {:get_until, encoding, prompt, mod, fun, args}, from, state, should_send) do
    module
    |> apply(:handle_get, [encoding, prompt, {:until, {mod, fun, args}}, from, state])
    |> to_genserver_info(from, should_send)
  end

  def marshal(module, {:get_chars, encoding, prompt, count}, from, state, should_send) do
    module
    |> apply(:handle_get, [encoding, prompt, {:chars, count}, from, state])
    |> to_genserver_info(from, should_send)
  end

  def marshal(module, {:get_line, encoding, prompt}, from, state, should_send) do
    module
    |> apply(:handle_get, [encoding, prompt, :line, from, state])
    |> to_genserver_info(from, should_send)
  end

  def marshal(module, {:setopts, opts}, from, state, should_send) do
    module
    |> apply(:handle_setopts, [opts, from, state])
    |> to_genserver_info(from, should_send)
  end

  def marshal(module, :getopts, from, state, should_send) do
    module
    |> apply(:handle_getopts, [from, state])
    |> to_genserver_info(from, should_send)
  end

  def marshal(module, {:get_geometry, dimension}, from, state, should_send) do
    module
    |> apply(:handle_geometry, [dimension, from, state])
    |> to_genserver_info(from, should_send)
  end

  def marshal(_module, {:requests, []}, from, state, _) do
    # this is only callable if the requests list is empty, which should not happen.
    reply(from, {:error, :request})
    {:noreply, state}
  end

  def marshal(module, {:requests, [last]}, from, state, {:stop, reason, _}) do
    # send the last response
    case marshal(module, last, from, state, true) do
      {:noreply, new_state} ->
        {:stop, reason, new_state}

      stop = {:stop, _, _} ->
        stop
    end
  end

  def marshal(module, {:requests, [last]}, from, state, _) do
    marshal(module, last, from, state, true)
  end

  def marshal(module, {:requests, [this | rest]}, from, state, maybe_stop) do
    case marshal(module, this, from, state, false) do
      {{:noreply, new_state}, _} ->
        marshal(module, {:requests, rest}, from, new_state, maybe_stop)

      {{:noreply, new_state, _}, _} ->
        marshal(module, {:requests, rest}, from, new_state, maybe_stop)

      {stop = {:stop, _, new_state}, _} ->
        marshal(module, {:requests, rest}, from, new_state, stop)
    end
  end

  def marshal(module, other, from, state, should_send) do
    result =
      if function_exported?(module, :handle_request, 3) do
        module.handle_request(other, from, state)
      else
        {:error, :request, state}
      end

    to_genserver_info(result, from, should_send)
  end

  defp to_genserver_info(result, from, should_send) do
    {result, reply} =
      case result do
        {:ok, reply, new_state} ->
          {{:noreply, new_state}, {:ok, reply}}

        {:ok, new_state} ->
          {{:noreply, new_state}, :ok}

        {:error, reason, new_state} ->
          {{:noreply, new_state}, {:error, reason}}

        noreply = {:noreply, _} ->
          {noreply, nil}

        noreply = {:noreply, _, _} ->
          {noreply, nil}

        {:reply, reply, new_state} ->
          {{:noreply, new_state}, reply}

        {:reply, reply, new_state, extra} ->
          {{:noreply, new_state, extra}, reply}

        {:stop, reason, reply, state} ->
          {{:stop, reason, state}, reply}
      end

    cond do
      should_send and reply ->
        reply(from, reply)
        result

      should_send ->
        result

      true ->
        {result, reply}
    end
  end
end
