defmodule MoolahWeb.LandingLive do
  @moduledoc """
  Renders the landing and onboarding entry experience for Moolah.

  The view presents a three-step onboarding preview inspired by the
  `~/Projects/Personal/moolah_page` layout while enabling real account
  registration directly within step one.

  ## Examples

      iex> MoolahWeb.LandingLive.step_ids()
      ["create-account", "connect-account", "start-tracking"]
  """

  use MoolahWeb, :live_view

  alias AshAuthentication.Info
  alias AshAuthentication.Phoenix.Components.Helpers
  alias AshPhoenix.Form
  alias Moolah.Accounts.User

  @auth_routes_prefix "/auth"
  @default_step "create-account"

  @step_cards [
    %{
      id: "create-account",
      title: "Create account",
      description: "Quick signup with your email. Takes about 30 seconds."
    },
    %{
      id: "connect-account",
      title: "Connect a financial account",
      description: "Choose your bank and keep balances in sync."
    },
    %{
      id: "start-tracking",
      title: "Start tracking",
      description: "Watch your cash flow and investments update instantly."
    }
  ]

  @bank_names [
    "Nubank",
    "Itaú",
    "Bradesco",
    "Banco do Brasil",
    "Santander",
    "Caixa",
    "Inter",
    "BTG",
    "Wise",
    "Nomad",
    "Other bank"
  ]

  @doc """
  Returns the ordered list of onboarding step identifiers.

  ## Examples

      iex> MoolahWeb.LandingLive.step_ids()
      ["create-account", "connect-account", "start-tracking"]
  """
  @spec step_ids() :: [String.t()]
  def step_ids do
    Enum.map(@step_cards, & &1.id)
  end

  @impl Phoenix.LiveView
  @doc false
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    strategy = Info.strategy!(User, :password)
    registration_form = build_registration_form(strategy)
    form = to_form(registration_form)

    {:ok,
     socket
     |> assign(:selected_step, @default_step)
     |> assign(:step_cards, @step_cards)
     |> assign(:bank_names, @bank_names)
     |> assign(:password_strategy, strategy)
     |> assign(:registration_form, registration_form)
     |> assign(:form, form)
     |> assign(:form_name, form.name)
     |> assign(:full_name, nil)
     |> assign_new(:current_scope, fn -> nil end)}
  end

  @impl Phoenix.LiveView
  @doc false
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("select-step", %{"step" => step}, socket) do
    selected_step = if step in step_ids(), do: step, else: @default_step

    {:noreply, assign(socket, :selected_step, selected_step)}
  end

  def handle_event("register-change", params, socket) do
    {form_params, full_name} =
      split_registration_params(params, socket.assigns.form_name, socket.assigns.full_name)

    registration_form =
      socket.assigns.registration_form
      |> Form.validate(form_params, errors: false)

    {:noreply,
     socket
     |> assign(:registration_form, registration_form)
     |> assign(:form, to_form(registration_form))
     |> assign(:full_name, full_name)}
  end

  def handle_event("register-submit", params, socket) do
    {form_params, full_name} =
      split_registration_params(params, socket.assigns.form_name, socket.assigns.full_name)

    socket = assign(socket, :full_name, full_name)

    if socket.assigns.password_strategy.sign_in_tokens_enabled? do
      submit_with_sign_in(socket, form_params)
    else
      submit_without_sign_in(socket, form_params)
    end
  end

  @impl Phoenix.LiveView
  @doc false
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      show_header={false}
      main_class="p-0"
      container_class="w-full"
    >
      <div class="landing-root landing-font relative min-h-screen overflow-hidden text-slate-100">
        <div class="absolute inset-0 bg-[radial-gradient(circle_at_top,_rgba(168,85,247,0.18),_transparent_55%)]" />
        <div class="absolute inset-0 bg-[radial-gradient(circle_at_30%_80%,_rgba(56,189,248,0.12),_transparent_45%)]" />

        <div class="pointer-events-none absolute inset-0">
          <div class="landing-float landing-float-slow absolute -top-24 left-[-4rem] h-72 w-72 rounded-full bg-purple-500/20 blur-[120px]" />
          <div class="landing-float landing-float-fast absolute top-24 right-[-6rem] h-80 w-80 rounded-full bg-fuchsia-400/20 blur-[140px]" />
          <div class="landing-float landing-float-medium absolute bottom-[-5rem] left-[20%] h-64 w-64 rounded-full bg-indigo-400/20 blur-[120px]" />
        </div>

        <div class="relative mx-auto flex w-full max-w-6xl flex-col px-6 pb-20 pt-10 sm:px-8 lg:px-10">
          <header id="landing-header" class="landing-header flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="landing-logo-badge flex size-10 items-center justify-center rounded-2xl bg-purple-500/20">
                <.icon name="hero-banknotes" class="size-5 text-purple-200" />
              </div>
              <div class="landing-header-text">
                <p class="text-xs uppercase tracking-[0.24em] text-purple-200/70">Moolah</p>
                <p class="text-sm font-semibold text-slate-100">Personal finance made calm.</p>
              </div>
            </div>
            <div class="hidden items-center gap-3 md:flex">
              <.link
                id="landing-header-sign-in"
                navigate={~p"/sign-in"}
                class="landing-header-link text-sm font-semibold text-slate-200/80 transition hover:text-white"
              >
                Sign in
              </.link>
              <.link
                id="landing-header-create"
                navigate={~p"/register"}
                class="landing-outline-button rounded-full border border-purple-400/60 px-4 py-2 text-sm font-semibold text-purple-100 transition hover:border-purple-300 hover:text-white"
              >
                Create account
              </.link>
              <Layouts.theme_toggle />
            </div>
          </header>

          <section
            id="landing-hero"
            class="mt-16 grid gap-12 lg:grid-cols-[minmax(0,1.05fr)_minmax(0,1fr)] lg:items-start"
          >
            <div class="space-y-8">
              <div class="space-y-5">
                <p class="landing-muted text-xs font-semibold uppercase tracking-[0.24em] text-purple-200/70">
                  Quick setup · Three steps
                </p>
                <h1 class="landing-heading text-4xl font-semibold leading-tight text-white sm:text-5xl">
                  Let's get you started with a calmer money routine.
                </h1>
                <p class="landing-subtitle max-w-xl text-base text-slate-200/80 sm:text-lg">
                  Connect your Brazilian accounts, track every transaction, and see your investments
                  grow with clarity.
                </p>
              </div>
              <div class="flex flex-wrap items-center gap-4">
                <.link
                  id="landing-primary-cta"
                  navigate={~p"/register"}
                  class="inline-flex items-center gap-2 rounded-full bg-purple-500 px-6 py-3 text-sm font-semibold text-white transition hover:bg-purple-400"
                >
                  Create account <.icon name="hero-arrow-right" class="size-4" />
                </.link>
                <.link
                  id="landing-secondary-cta"
                  navigate={~p"/sign-in"}
                  class="landing-outline-button inline-flex items-center gap-2 rounded-full border border-purple-300/60 px-6 py-3 text-sm font-semibold text-purple-100 transition hover:border-purple-200 hover:text-white"
                >
                  Sign in
                </.link>
              </div>
              <div class="landing-muted flex items-center gap-3 text-sm text-slate-200/70">
                <div class="flex -space-x-2">
                  <div class="size-8 rounded-full border border-white/10 bg-gradient-to-br from-purple-400/80 to-fuchsia-500/80" />
                  <div class="size-8 rounded-full border border-white/10 bg-gradient-to-br from-purple-300/80 to-pink-400/80" />
                  <div class="size-8 rounded-full border border-white/10 bg-gradient-to-br from-indigo-300/80 to-purple-400/80" />
                </div>
                <p>Trusted by founders building their financial freedom.</p>
              </div>
            </div>

            <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]">
              <div class="space-y-4">
                <p class="landing-muted text-xs uppercase tracking-[0.2em] text-purple-200/70">
                  Onboarding
                </p>
                <div class="space-y-3">
                  <button
                    :for={step <- @step_cards}
                    id={"landing-step-#{step.id}"}
                    type="button"
                    phx-click="select-step"
                    phx-value-step={step.id}
                    class={[
                      "landing-card group w-full rounded-2xl border px-4 py-4 text-left transition",
                      "hover:-translate-y-0.5 hover:shadow-lg hover:shadow-purple-500/10",
                      if(@selected_step == step.id,
                        do: "border-purple-400/70 shadow-lg shadow-purple-500/20",
                        else: "border-white/5"
                      )
                    ]}
                  >
                    <div class="flex items-center justify-between">
                      <p class="landing-step-title text-sm font-semibold text-white">
                        {step.title}
                      </p>
                      <span
                        data-active={@selected_step == step.id}
                        class={[
                          "landing-step-badge inline-flex size-7 items-center justify-center rounded-full border text-xs",
                          @selected_step == step.id && "landing-step-badge-active",
                          @selected_step != step.id && "landing-step-badge-inactive"
                        ]}
                      >
                        {step_number(step.id)}
                      </span>
                    </div>
                    <p class="landing-step-desc mt-2 text-sm text-slate-200/70">
                      {step.description}
                    </p>
                  </button>
                </div>

                <div id="landing-progress" class="flex items-center gap-2">
                  <div
                    :for={step <- @step_cards}
                    class={[
                      "h-1.5 w-8 rounded-full transition",
                      if(@selected_step == step.id, do: "bg-purple-400", else: "bg-white/10")
                    ]}
                  />
                </div>
              </div>

              <div
                id="landing-step-detail"
                class="landing-panel rounded-3xl border border-white/10 p-6 shadow-2xl shadow-purple-500/10"
              >
                <%= case @selected_step do %>
                  <% "create-account" -> %>
                    <div class="space-y-5">
                      <div class="flex items-center gap-3">
                        <div class="landing-icon-badge flex size-10 items-center justify-center rounded-2xl bg-purple-500/20">
                          <.icon name="hero-user-plus" class="size-5 text-purple-200" />
                        </div>
                        <div>
                          <p class="landing-panel-title text-sm font-semibold text-white">
                            Create your account
                          </p>
                          <p class="landing-panel-subtitle text-xs text-slate-200/60">
                            Start with the essentials.
                          </p>
                        </div>
                      </div>
                      <.form
                        for={@form}
                        id="landing-register-form"
                        phx-change="register-change"
                        phx-submit="register-submit"
                        class="landing-form space-y-3"
                      >
                        <.input
                          name={"#{@form_name}[full_name]"}
                          id="landing-register-name"
                          label="Full name"
                          value={@full_name}
                          placeholder="Julia Mathias"
                          autocomplete="name"
                        />
                        <.input
                          field={@form[:email]}
                          id="landing-register-email"
                          type="email"
                          label="Email"
                          placeholder="julia@email.com"
                          autocomplete="email"
                        />
                        <.input
                          field={@form[:password]}
                          id="landing-register-password"
                          type="password"
                          label="Password"
                          placeholder="••••••••"
                          autocomplete="new-password"
                        />
                        <.input
                          field={@form[:password_confirmation]}
                          id="landing-register-password-confirmation"
                          type="password"
                          label="Confirm password"
                          placeholder="••••••••"
                          autocomplete="new-password"
                        />
                        <button
                          id="landing-register-submit"
                          type="submit"
                          class="mt-2 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-purple-500 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-purple-400"
                        >
                          Create account <.icon name="hero-arrow-right" class="size-4" />
                        </button>
                        <p class="landing-panel-subtitle text-xs text-slate-200/60">
                          By continuing, you agree to our Terms of Service and Privacy Policy.
                        </p>
                      </.form>
                    </div>
                  <% "connect-account" -> %>
                    <div class="space-y-5">
                      <div class="flex items-center gap-3">
                        <div class="landing-icon-badge flex size-10 items-center justify-center rounded-2xl bg-purple-500/20">
                          <.icon name="hero-building-library" class="size-5 text-purple-200" />
                        </div>
                        <div>
                          <p class="landing-panel-title text-sm font-semibold text-white">
                            Connect a bank
                          </p>
                          <p class="landing-panel-subtitle text-xs text-slate-200/60">
                            Choose your primary account.
                          </p>
                        </div>
                      </div>
                      <div class="grid grid-cols-2 gap-3 sm:grid-cols-3">
                        <button
                          :for={bank <- @bank_names}
                          type="button"
                          class="landing-bank-button rounded-2xl border border-white/10 bg-slate-950/50 px-3 py-3 text-left text-xs font-semibold text-slate-200 transition hover:border-purple-400/50 hover:text-white"
                        >
                          {bank}
                        </button>
                      </div>
                      <button
                        id="landing-bank-continue"
                        type="button"
                        class="landing-outline-button inline-flex w-full items-center justify-center gap-2 rounded-xl border border-purple-300/70 px-4 py-2.5 text-sm font-semibold text-purple-100 transition hover:border-purple-200"
                      >
                        Continue <.icon name="hero-arrow-right" class="size-4" />
                      </button>
                    </div>
                  <% "start-tracking" -> %>
                    <div class="space-y-5">
                      <div class="flex items-center gap-3">
                        <div class="landing-icon-badge flex size-10 items-center justify-center rounded-2xl bg-purple-500/20">
                          <.icon name="hero-sparkles" class="size-5 text-purple-200" />
                        </div>
                        <div>
                          <p class="landing-panel-title text-sm font-semibold text-white">
                            You are ready
                          </p>
                          <p class="landing-panel-subtitle text-xs text-slate-200/60">
                            Your dashboard is prepared.
                          </p>
                        </div>
                      </div>
                      <div class="landing-summary-card rounded-2xl border border-white/10 bg-slate-950/50 p-4">
                        <p class="landing-summary-text text-sm text-slate-200/80">
                          We will automatically create your workspace, pull balances, and show weekly
                          insights on day one.
                        </p>
                        <div class="landing-summary-status mt-4 flex items-center gap-2 text-xs text-purple-200/80">
                          <.icon name="hero-check-circle" class="size-4" /> Setup complete
                        </div>
                      </div>
                      <button
                        id="landing-start-button"
                        type="button"
                        class="inline-flex w-full items-center justify-center gap-2 rounded-xl bg-purple-500 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-purple-400"
                      >
                        Start tracking <.icon name="hero-arrow-right" class="size-4" />
                      </button>
                    </div>
                <% end %>
              </div>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @spec submit_with_sign_in(Phoenix.LiveView.Socket.t(), map()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  defp submit_with_sign_in(socket, form_params) do
    case Form.submit(socket.assigns.registration_form, params: form_params, read_one?: true) do
      {:ok, user} ->
        redirect_path =
          Helpers.auth_path(
            socket,
            Info.authentication_subject_name!(socket.assigns.password_strategy.resource),
            @auth_routes_prefix,
            socket.assigns.password_strategy,
            :sign_in_with_token,
            token: user.__metadata__.token
          )

        {:noreply, redirect(socket, to: redirect_path)}

      {:error, registration_form} ->
        Helpers.debug_form_errors(registration_form)

        {:noreply,
         socket
         |> assign(:registration_form, registration_form)
         |> assign(:form, to_form(registration_form))}
    end
  end

  @spec submit_without_sign_in(Phoenix.LiveView.Socket.t(), map()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  defp submit_without_sign_in(socket, form_params) do
    case Form.submit(socket.assigns.registration_form, params: form_params, read_one?: true) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account created. Please sign in to continue.")
         |> push_navigate(to: ~p"/sign-in")}

      {:error, registration_form} ->
        Helpers.debug_form_errors(registration_form)

        {:noreply,
         socket
         |> assign(:registration_form, registration_form)
         |> assign(:form, to_form(registration_form))}
    end
  end

  @spec split_registration_params(map(), String.t(), String.t() | nil) ::
          {map(), String.t() | nil}
  defp split_registration_params(params, form_name, fallback_full_name) do
    form_params = Map.get(params, form_name, %{})
    full_name = Map.get(form_params, "full_name", fallback_full_name)

    {Map.drop(form_params, ["full_name"]), full_name}
  end

  @spec build_registration_form(AshAuthentication.Strategy.t()) :: AshPhoenix.Form.t()
  defp build_registration_form(strategy) do
    domain = Info.authentication_domain!(strategy.resource)
    subject_name = Info.authentication_subject_name!(strategy.resource)

    context =
      %{}
      |> maybe_add_token_context(strategy)
      |> Map.put(:strategy, strategy)
      |> Map.update(
        :private,
        %{ash_authentication?: true},
        &Map.put(&1, :ash_authentication?, true)
      )

    Form.for_action(strategy.resource, strategy.register_action_name,
      domain: domain,
      as: to_string(subject_name),
      context: context,
      id: "landing-register"
    )
  end

  @spec maybe_add_token_context(map(), AshAuthentication.Strategy.t()) :: map()
  defp maybe_add_token_context(context, strategy) do
    if Map.get(strategy, :sign_in_tokens_enabled?) do
      Map.put(context, :token_type, :sign_in)
    else
      context
    end
  end

  @spec step_number(String.t()) :: String.t()
  defp step_number(step_id) do
    step_ids()
    |> Enum.with_index(1)
    |> Enum.find_value("1", fn {id, index} -> if id == step_id, do: Integer.to_string(index) end)
  end
end
