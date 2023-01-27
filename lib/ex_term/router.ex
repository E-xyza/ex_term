defmodule ExTerm.Router do
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, [module | opts]) do
    Plug.Conn.put_session(conn, "exterm-backend", {module, opts})
  end

  defmacro live_term(route, module_or_opts, opts \\ [])

  defmacro live_term(route, module, opts) when is_atom(module) do
    id = :erlang.phash2(Map.take(__CALLER__, [:file, :line]))
    pipeline_name = :"exterm-pipeline-#{id}"

    quote do
      pipeline unquote(pipeline_name) do
        plug ExTerm.Router, [unquote(module) | unquote(opts)]
      end

      pipe_through unquote(pipeline_name)

      live unquote(route), ExTerm
    end
  end

  defmacro live_term(route, opts, []) when is_list(opts) do
    id = :erlang.phash2(Map.take(__CALLER__, [:file, :line]))
    pipeline_name = :"exterm-pipeline-#{id}"

    quote do
      pipeline unquote(pipeline_name) do
        plug ExTerm.Router, [ExTerm.TerminalBackend | unquote(opts)]
      end

      pipe_through unquote(pipeline_name)

      live unquote(route), ExTerm
    end
  end
end
