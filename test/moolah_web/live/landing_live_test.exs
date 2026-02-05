defmodule MoolahWeb.LandingLiveTest do
  use MoolahWeb.ConnCase

  import Phoenix.LiveViewTest

  test "GET / renders landing content", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#landing-primary-cta")
    assert has_element?(view, "#landing-step-create-account")
    assert has_element?(view, "#landing-step-connect-account")
    assert has_element?(view, "#landing-step-start-tracking")
    assert has_element?(view, "#landing-register-form")
    assert has_element?(view, "#landing-register-submit")
  end
end
