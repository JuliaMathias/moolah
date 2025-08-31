defmodule MoolahWeb.ProxyEndpoint do
  @moduledoc """
  Proxy endpoint for Beacon CMS integration.

  Routes CMS-related requests through Beacon and falls back
  to the main application endpoint for other requests.
  """
  use Beacon.ProxyEndpoint,
    otp_app: :moolah,
    session_options: Application.compile_env!(:moolah, :session_options),
    fallback: MoolahWeb.Endpoint
end
