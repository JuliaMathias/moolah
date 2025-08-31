defmodule Moolah.MixProject do
  use Mix.Project

  def project do
    [
      app: :moolah,
      version: "0.1.0",
      elixir: "~> 1.18.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :dev,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_add_apps: [:ex_unit],
        plt_add_deps: :app_tree,
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Moolah.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:ash, "~> 3.5"},
      {:ash_admin, "~> 0.13"},
      {:ash_archival, "~> 2.0"},
      {:ash_authentication, "~> 4.9"},
      {:ash_authentication_phoenix, "~> 2.10"},
      {:ash_double_entry, "~> 1.0"},
      {:ash_money, "~> 0.2.4"},
      {:ash_oban, "~> 0.4"},
      {:ash_paper_trail, "~> 0.5.6"},
      {:ash_phoenix, "~> 2.3"},
      {:ash_postgres, "~> 2.6"},
      {:bandit, "~> 1.8"},
      {:bcrypt_elixir, "~> 3.3"},
      {:beacon, "~> 0.5"},
      {:beacon_live_admin, "~> 0.4"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:dns_cluster, "~> 0.2"},
      {:ecto_sql, "~> 3.13"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:ex_money_sql, "~> 1.11"},
      {:finch, "~> 0.20"},
      {:floki, ">= 0.30.0"},
      {:gettext, "~> 0.26"},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:jason, "~> 1.4"},
      {:live_debugger, "~> 0.4", only: [:dev]},
      {:mishka_chelekom, "~> 0.0", only: [:dev]},
      {:oban, "~> 2.20"},
      {:phoenix, "~> 1.8"},
      {:phoenix_ecto, "~> 4.6"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_dashboard, "~> 0.8.7"},
      {:phoenix_live_reload, "~> 1.6", only: :dev},
      {:phoenix_live_view, "~> 1.1"},
      {:picosat_elixir, "~> 0.2"},
      {:postgrex, ">= 0.21.0"},
      {:sourceror, "~> 1.10", only: [:dev, :test]},
      {:swoosh, "~> 1.19"},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.3"},
      # Override to fix Elixir 1.18.4 compatibility
      {:ex_aws, "~> 2.5", override: true}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup", "assets.build", "run priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ash.setup --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind moolah", "esbuild moolah"],
      "assets.deploy": [
        "tailwind moolah --minify",
        "esbuild moolah --minify",
        "phx.digest"
      ],
      "phx.routes": ["phx.routes", "ash_authentication.phoenix.routes"]
    ]
  end
end
