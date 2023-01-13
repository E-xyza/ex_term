defmodule ExTerm.IexBackend.KeyBuffer do
  @moduledoc false

  # keybuffer is a list of keys that have been entered into the buffer already.

  @type t :: {:queue.queue([String.t]), [String.t]}

  @spec new :: t
  def new, do: {:queue.new(), []}

  @spec push(t, String.t) :: t
  def push({queue, this}, "Enter") do
    {:queue.in(this, queue), []}
  end

  def push({queue, this}, other_key) do
    {queue, [other_key | this]}
  end

  @spec pop(t) :: {:full, [String.t], t} | {:partial, [String.t], t}
  def pop({queue, this}) do
    case :queue.out(queue) do
      {{:value, item}, new_queue} ->
        {:full, item, {new_queue, this}}
      {:empty, _} ->
        {:partial, this, {:queue.new(), []}}
    end
  end
end
