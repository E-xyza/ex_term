defmodule ExTermTest.Console do
  @moduledoc false

  @doc """
  call from inside the console pid to create a synchronization point.
  """
  def sync(test_pid, payload \\ []) do
    ref = make_ref()
    send(test_pid, {:block, self(), ref, payload})

    receive do
      {:unblock, ^ref} -> :ok
    end
  end

  @doc """
  call from the test to free a synchronization point.
  """
  def unblock(lambda \\ &Function.identity/1) do
    receive do
      {:block, which, ref, payload} ->
        result = lambda.(payload)
        send(which, {:unblock, ref})
        result
      after 1000 ->
        raise "did not receive a block message"
    end
  end

  @spec hibernate :: no_return
  def hibernate do
    :erlang.hibernate(__MODULE__, :forever, [])
  end
end
