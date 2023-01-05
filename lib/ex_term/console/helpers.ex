defmodule ExTerm.Console.Helpers do
  defmacro defaccess({name, _, args = [console | _]}, do: block) do
    quote do
      def unquote(name)(unquote_splicing(args)) when is_accessible(unquote(console)) do
        target_node = node(custodian(unquote(console)))
        if target_node === node() do
          unquote(block)
        else
          :rpc.call(target_node, __MODULE__, unquote(name), unquote(args))
        end
      end
      def unquote(name)(unquote_splicing(args)) do
        raise ArgumentError, message: "incorrect permissions for the selected table"
      end
    end
  end

  defmacro defmut({name, _, args = [console | _]}, do: block) do
    quote do
      def unquote(name)(unquote_splicing(args)) when is_mutable(unquote(console)) do
        target_node = node(custodian(unquote(console)))
        if target_node === node() do
          unquote(block)
        else
          :rpc.call(target_node, __MODULE__, unquote(name), unquote(args))
        end
      end
      def unquote(name)(unquote_splicing(args)) do
        raise ArgumentError, message: "incorrect permissions for the selected table"
      end
    end
  end
end
