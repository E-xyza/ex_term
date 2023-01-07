defmodule ExTerm.Console.Helpers do
  @check_transaction Application.compile_env(:ex_term, :check_transaction, false)

  @doc """
  wraps code into a single execution unit that are run on the same node.

  note that there are two types:  `:mutate` and `:access` types.  all code in
  `:mutate` is guaranteed to be truly transactional with respect to the ets
  table with respect to other code guarded by this transaction macro.  code
  bundled in the `:access` type is not guaranteed to be transactional with
  respect to the ets table.
  """
  defmacro transaction(console, type, do: code) when type in [:mutate, :access] do
    import_statement =
      if __CALLER__.module === ExTerm.Console do
        [Kernel]
      else
        [
          ExTerm.Console,
          [
            only: [
              is_access_ok: 1,
              is_mutate_ok: 1,
              is_local: 1,
              custodian: 1,
              permission: 1,
              spinlock: 1
            ]
          ]
        ]
      end

    access_error =
      quote do
        console when not is_access_ok(console) ->
          raise "transaction in function #{__ENV__.function} running on #{inspect(self())} doesn't have access to #{permission(console)} console which is the responsibility of #{inspect(custodian(console))}"
      end

    mutate_error =
      quote do
        {console, :mutate} when not is_mutate_ok(console) ->
          raise "transaction in function #{__ENV__.function} running on #{inspect(self())} cannot mutate #{permission(console)} console which is the responsibility of #{inspect(custodian(console))}"
      end

    punt_nonlocal =
      quote do
        console when not is_local(console) ->
          console
          |> custodian
          |> node
          |> :erpc.call(lambda, [])
      end

    spinlock =
      quote do
        console when permission(console) === :public ->
          Helpers._lock(spinlock(console))
          result = lambda.()
          Helpers._unlock(spinlock(console))
          result
      end

    run_now =
      quote do
        _ -> lambda.()
      end

    prongs =
      case type do
        :access ->
          [access_error, punt_nonlocal, run_now]

        :mutate ->
          [mutate_error, punt_nonlocal, spinlock, run_now]
      end

    prongs = Enum.flat_map(prongs, & &1)

    quote do
      alias ExTerm.Console.Helpers

      import unquote_splicing(import_statement)

      lambda = fn -> unquote(code) end

      if Process.put(:exterm_in_transaction, unquote(type)) do
        raise "#{__ENV__.function} created a transaction when it was already in a transaction"
      end

      result =
        case unquote(console) do
          unquote(prongs)
        end

      Process.delete(:exterm_in_transaction)
      result
    end
  end

  def _lock(atomic) do
    case :atomics.compare_exchange(atomic, 1, 0, 1) do
      :ok -> :ok
      _ -> _lock(atomic)
    end
  end

  def _unlock(atomic) do
    :atomics.put(atomic, 1, 0)
  end

  @doc """
  creates a function that is tagged as an access function.

  If the application evironment variable `:exterm, :check_transaction` is set,
  and the function is not inside of a transaction, it will raise with an error.

  If you're developing exterm backends, you should have this environment
  variable set at a minimum in dev and test environments.
  """
  defmacro defaccess({name, _, args}, do: code) do
    check_transaction =
      if @check_transaction do
        quote bind_quoted: [name: name] do
          case Process.get(:exterm_in_transaction) do
            tx when tx in [:mutate, :access] ->
              :ok

            _ ->
              raise "function #{name} must be in a transaction"
          end
        end
      end

    quote do
      def unquote(name)(unquote_splicing(args)) do
        unquote(check_transaction)
        unquote(code)
      end
    end
  end

  @doc """
  creates a function that is tagged as a mutation.  The console argument must be the
  first argument.
  """
  defmacro defmut({name, _, args}, do: code) do
    check_transaction =
      if @check_transaction do
        quote bind_quoted: [name: name] do
          case Process.get(:exterm_in_transaction) do
            :mutate ->
              :ok

            :access ->
              raise "function #{name} must be in a mutation transaction, it is only in an access transaction"

            _ ->
              raise "function #{name} must be in a transaction"
          end
        end
      end

    quote do
      def unquote(name)(unquote_splicing(args)) do
        unquote(check_transaction)
        unquote(code)
      end
    end
  end
end
