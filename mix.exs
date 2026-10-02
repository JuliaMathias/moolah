defmodule Moolah.MixProject do
  use Mix.Project

  @doc "Returns the application build configuration."
  @spec project() :: keyword()
  def project do
    [
      app: :moolah,
      version: "0.1.0",
      elixir: "~> 1.20.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :dev,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      test_coverage: [tool: ExCoveralls],
      listeners: [Phoenix.CodeReloader],
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
  @doc "Returns the OTP application configuration."
  @spec application() :: keyword()
  def application do
    [
      mod: {Moolah.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  @doc "Configures the environment for project Mix commands."
  @spec cli() :: keyword()
  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  @doc false
  @spec elixirc_paths(atom()) :: [String.t()]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  @doc false
  @spec deps() :: [tuple()]
  defp deps do
    [
      {:mishka_chelekom, "~> 0.0.9", only: [:dev]},
      {:ash, "~> 3.33.11"},
      {:ash_admin, "~> 1.3.2"},
      {:ash_authentication, "~> 4.15.0"},
      {:ash_authentication_phoenix, "~> 2.17.4"},
      {:ash_double_entry, "~> 1.0.19"},
      {:ash_money, "~> 0.2.6"},
      {:ash_oban, "~> 0.9.0"},
      {:ash_phoenix, "~> 2.3.25"},
      {:ash_postgres, "~> 2.13.1"},
      {:bandit, "~> 1.12.5"},
      {:splode, "~> 0.3.2", override: true},
      {:reactor, "~> 1.0.7"},
      {:bcrypt_elixir, "~> 3.3.2"},
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.8", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18.5", only: :test},
      {:ecto_sql, "~> 3.14.0"},
      {:esbuild, "~> 0.10.0", runtime: Mix.env() == :dev},
      {:localize, "~> 1.3.0"},
      {:ex_money_sql, "~> 2.1.0"},
      {:igniter, "~> 0.8.4"},
      {:gettext, "~> 1.0.2"},
      {:jason, "~> 1.4.5"},
      {:lazy_html, "~> 0.1.13", only: :test},
      {:live_debugger, "~> 1.0.2", only: [:dev]},
      {:live_isolated_component, "~> 0.11.0", only: [:test]},
      {:oban, "~> 2.24.1"},
      {:oban_web, "~> 2.13.0"},
      {:phoenix, "~> 1.8.15"},
      {:phoenix_ecto, "~> 4.7.0"},
      {:phoenix_html, "~> 4.3.0"},
      {:phoenix_live_dashboard, "~> 0.9.1"},
      {:phoenix_live_reload, "~> 1.7.0", only: :dev},
      {:phoenix_live_view, "~> 1.2.12"},
      {:picosat_elixir, "~> 0.2.3"},
      {:postgrex, "~> 0.22.4"},
      {:sourceror, "~> 1.12.3"},
      {:req, "~> 0.7.4"},
      {:swoosh, "~> 1.28.1"},
      {:tailwind, "~> 0.5.1", runtime: Mix.env() == :dev},
      {:tidewave, "~> 0.9.1", only: [:dev]},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.2.0"},
      {:telemetry_poller, "~> 1.3.0"},
      {:dns_cluster, "~> 0.3.1"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  @doc false
  @spec aliases() :: keyword([String.t()])
  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup", "assets.build", "run priv/repo/seeds.exs"],
      "devcontainer.setup": ["deps.get", "assets.setup", "ash.setup --quiet"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ash.setup --quiet", "test"],
      "assets.setup": [
        "localize.download_locales",
        "tailwind.install --if-missing",
        "esbuild.install --if-missing"
      ],
      "assets.build": ["compile", "tailwind moolah", "esbuild moolah"],
      "assets.deploy": [
        "localize.download_locales",
        "tailwind moolah --minify",
        "esbuild moolah --minify",
        "phx.digest"
      ],
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format",
        "localize.download_locales",
        "test",
        "credo --strict",
        "coveralls"
      ],
      "phx.routes": ["phx.routes", "ash_authentication.phoenix.routes"]
    ]
  end
end
