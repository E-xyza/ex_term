defmodule ExTerm.MixProject do
  use Mix.Project

  @development [:dev, :test]

  def project do
    [
      app: :ex_term,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(Mix.env()),
      deps: deps()
    ]
  end

  def application do
    List.wrap(
      if Mix.env() in @development do
        [
          mod: {ExTerm.Application, []},
          extra_applications: [:logger, :runtime_tools]
        ]
      end
    )
  end

  defp elixirc_paths(env) when env in @development, do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    in_dev = Mix.env() in @development
    [
      {:phoenix, "~> 1.6.15", optional: !in_dev},
      {:phoenix_html, "~> 3.0", optional: !in_dev},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.17.5", optional: !in_dev},
      {:floki, ">= 0.30.0", only: :test},
      {:esbuild, "~> 0.4", runtime: Mix.env() == :dev},
      {:plug_cowboy, "~> 2.5", optional: !in_dev}
    ]
  end

  defp aliases(env) do
    List.wrap(
      if env in @development do
        [
          setup: ["deps.get"],
          "assets.deploy": ["esbuild default --minify", "phx.digest"]
        ]
      end
    )
  end
end
