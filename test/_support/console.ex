defmodule ExTermTest.Console do
  @moduledoc false

  @doc """
  call from inside the console pid to create a synchronization point.
  """
  def sync(test_pid) do
    ref = make_ref()

    send(test_pid, {:block, self(), ref})
    receive do {:unblock, ^ref} -> :ok end
  end

  @doc """
  call from the test to free a synchronization point.
  """
  def unblock do
    receive do
      {:block, which, ref} -> send(which, {:unblock, ref})
    end
  end

  @spec hibernate :: no_return
  def hibernate do
    :erlang.hibernate(__MODULE__, :forever, [])
  end
end
