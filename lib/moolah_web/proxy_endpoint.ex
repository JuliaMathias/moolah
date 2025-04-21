defmodule MoolahWeb.ProxyEndpoint do
  use Beacon.ProxyEndpoint,
    otp_app: :moolah,
    session_options: Application.compile_env!(:moolah, :session_options),
    fallback: MoolahWeb.Endpoint
end
