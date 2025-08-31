defmodule MoolahWeb.Router do
  use MoolahWeb, :router

  use Beacon.LiveAdmin.Router
  use Beacon.Router
  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :beacon_admin do
    plug Beacon.LiveAdmin.Plug
  end

  pipeline :beacon do
    plug Beacon.Plug
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MoolahWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/" do
    pipe_through [:browser, :beacon_admin]
    beacon_live_admin "/cms/admin"
  end

  scope "/", MoolahWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_routes do
      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {MoolahWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {MoolahWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {MoolahWeb.LiveUserAuth, :live_no_user}
    end
  end

  scope "/", MoolahWeb do
    pipe_through :browser
    # Home route - enabled when Beacon CMS is not configured
    if Application.compile_env(:beacon, :cms) == [] do
      get "/", PageController, :home
    end

    get "/removed", PageController, :home
    auth_routes AuthController, Moolah.Accounts.User, path: "/auth"
    sign_out_route AuthController

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{MoolahWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    MoolahWeb.AuthOverrides,
                    AshAuthentication.Phoenix.Overrides.Default
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [MoolahWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove this if you do not use the confirmation strategy
    confirm_route Moolah.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [MoolahWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
  end

  # Other scopes may use custom stacks.
  # scope "/api", MoolahWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:moolah, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MoolahWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  if Application.compile_env(:moolah, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end

  # Only enable Beacon routes if CMS is configured
  if Application.compile_env(:beacon, :cms) != [] do
    scope "/", alias: MoolahWeb do
      pipe_through [:browser, :beacon]
      beacon_site "/", site: :cms
    end
  end
end
