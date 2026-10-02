defmodule MoolahWeb.LandingLiveTest do
  use MoolahWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Moolah.Accounts.User

  @valid_params %{
    first_name: "Test",
    last_name: "User",
    email: "landing-test@example.com",
    password: "supersecret123",
    password_confirmation: "supersecret123"
  }

  test "GET / renders landing content", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#landing-primary-cta")
    assert has_element?(view, "#landing-secondary-cta")
    assert has_element?(view, "#landing-step-create-account")
    assert has_element?(view, "#landing-step-connect-account")
    assert has_element?(view, "#landing-step-start-tracking")
    assert has_element?(view, "#landing-register-form")
    assert has_element?(view, "#landing-register-submit")
  end

  test "selecting a step swaps the detail panel", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> element("#landing-step-connect-account") |> render_click()
    assert has_element?(view, "#landing-bank-continue")
    refute has_element?(view, "#landing-register-form")

    view |> element("#landing-step-start-tracking") |> render_click()
    assert has_element?(view, "#landing-start-button")

    view |> element("#landing-step-create-account") |> render_click()
    assert has_element?(view, "#landing-register-form")
  end

  test "lists the Brazilian banks on the connect step", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html = view |> element("#landing-step-connect-account") |> render_click()

    for bank <- ["Nubank", "Itaú", "Bradesco", "Banco do Brasil", "Santander", "Caixa"] do
      assert html =~ bank
    end
  end

  test "valid registration creates the user and advances to the next step", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#landing-register-form", user: @valid_params)
    |> render_submit()

    assert has_element?(view, "#landing-register-message[data-status='success']")

    assert [user] = Ash.read!(User, authorize?: false)
    assert user.first_name == "Test"
    assert user.last_name == "User"
    assert to_string(user.email) == "landing-test@example.com"

    send(view.pid, :advance_onboarding_step)
    assert render(view) =~ "landing-bank-continue"
  end

  test "invalid registration shows the banner and per-field errors", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#landing-register-form",
      user: %{
        first_name: "",
        last_name: "",
        email: "",
        password: "short",
        password_confirmation: "different"
      }
    )
    |> render_submit()

    assert has_element?(view, "#landing-register-message[data-status='error']")

    assert has_element?(view, "#landing-register-form p", "is required")

    assert has_element?(
             view,
             "#landing-register-form p",
             "length must be greater than or equal to 8"
           )

    assert has_element?(view, "#landing-register-form p", "does not match")
    assert Ash.read!(User, authorize?: false) == []
  end

  test "does not advance the step when registration failed", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#landing-register-form", user: %{@valid_params | password_confirmation: "nope"})
    |> render_submit()

    send(view.pid, :advance_onboarding_step)
    assert has_element?(view, "#landing-register-form")
  end

  test "ignores unexpected messages", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    send(view.pid, {:email, %{}})
    assert has_element?(view, "#landing-register-form")
  end
end
