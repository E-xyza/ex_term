defmodule ExTerm.TerminalSupervisor do
  def start_link(opts), do: Task.Supervisor.start_link(opts ++ [name: __MODULE__])

  # defdelegate child_spec(params), to: Task.Supervisor

  def child_spec(params) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[]]},
      type: :supervisor
    }
  end

  def start_child(task) do
    # we have to wrap the task in its own lambda to avoid a race condition in assigning the group_leader for the
    # lambda.
    group_leader = self()

    wrapped = fn ->
      Process.link(group_leader)
      :erlang.group_leader(group_leader, self())

      case task do
        {m, f, a} ->
          apply(m, f, a)

        task when is_function(task, 0) ->
          task.()
      end
    end

    Task.Supervisor.start_child(__MODULE__, wrapped)
  end

  def start_child(m, f, a), do: start_child({m, f, a})
end
