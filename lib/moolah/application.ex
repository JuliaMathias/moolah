defmodule Moolah.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    beacon_children =
      case Application.get_env(:beacon, :cms) do
        [] -> []
        cms_config when not is_nil(cms_config) -> [{Beacon, [sites: [cms_config]]}]
        _ -> []
      end

    children = [
      MoolahWeb.Telemetry,
      Moolah.Repo,
      {DNSCluster, query: Application.get_env(:moolah, :dns_cluster_query) || :ignore}
    ] ++ beacon_children ++ [
      {Oban,
       AshOban.config(
         Application.fetch_env!(:moolah, :ash_domains),
         Application.fetch_env!(:moolah, Oban)
       )},
      # Start the Finch HTTP client for sending emails
      # Start a worker by calling: Moolah.Worker.start_link(arg)
      # {Moolah.Worker, arg},
      # Start to serve requests, typically the last entry
      {Phoenix.PubSub, name: Moolah.PubSub},
      {Finch, name: Moolah.Finch},
      MoolahWeb.CmsEndpoint,
      MoolahWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :moolah]},
      MoolahWeb.ProxyEndpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Moolah.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MoolahWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
