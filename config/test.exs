import Config
config :moolah, Oban, testing: :manual
config :moolah, token_signing_secret: "KsQjw4A7TxkbinayOT45KnXSx05/bX/Z"
config :bcrypt_elixir, log_rounds: 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :moolah, Moolah.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "moolah_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :moolah, MoolahWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "tfgLrgyhB1QMU3DKBLgh6zvQYosw9qRRtRFJrskuWNGKXrWeMPxkLy0RlVPaIvND",
  server: false

# In test we don't send emails
config :moolah, Moolah.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Disable Beacon CMS during tests to avoid startup issues
config :beacon, cms: []
