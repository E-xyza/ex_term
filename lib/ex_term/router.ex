defmodule ExTerm.Router do
  @behaviour Plug

  alias ExTerm.CSS
  require CSS

  @css_builtins CSS.builtins()

  def init([module | opts]) do
    new_opts = opts
    |> Keyword.put_new(:css, :default)
    |> Enum.map(fn
      {:css, builtin} when builtin in @css_builtins ->
        {:css, Map.fetch!(CSS.default_css_map(), builtin)}

      {:css, {:priv, app, file_path}} ->
        css_content =
          app
          |> :code.priv_dir()
          |> Path.join(file_path)
          |> File.read!()

        {:css, css_content}

      {:css, option} ->
        raise "unsupported CSS option #{inspect(option)}, must a default atom (one of #{inspect(@css_builtins)}) or `{:priv, app, path}`"

      other ->
        other
    end)

    [module | new_opts]
  end

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
