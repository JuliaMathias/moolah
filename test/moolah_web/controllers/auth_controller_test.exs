defmodule MoolahWeb.AuthControllerTest do
  @moduledoc false
  use MoolahWeb.ConnCase, async: true

  describe "failure/3" do
    test "redirects to sign-in with generic error for invalid credentials", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> fetch_flash()
        |> MoolahWeb.AuthController.failure({:password, :sign_in}, :invalid_credentials)

      assert redirected_to(conn) == ~p"/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Incorrect email or password"
    end

    test "shows special message for unconfirmed user error", %{conn: conn} do
      error = %AshAuthentication.Errors.AuthenticationFailed{
        caused_by: %Ash.Error.Forbidden{
          errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
        }
      }

      conn =
        conn
        |> init_test_session(%{})
        |> fetch_flash()
        |> MoolahWeb.AuthController.failure({:password, :sign_in}, error)

      assert redirected_to(conn) == ~p"/sign-in"
      flash_error = Phoenix.Flash.get(conn.assigns.flash, :error)
      assert flash_error =~ "You have already signed in another way"
      assert flash_error =~ "but have not confirmed your account"
    end
  end

  describe "sign_out/2" do
    test "clears session and redirects to home", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{user_id: "test-user"})
        |> fetch_flash()
        |> MoolahWeb.AuthController.sign_out(%{})

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "You are now signed out"
    end

    test "redirects to return_to path when set", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{user_id: "test-user", return_to: "/custom-path"})
        |> fetch_flash()
        |> MoolahWeb.AuthController.sign_out(%{})

      assert redirected_to(conn) == "/custom-path"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "You are now signed out"
    end
  end
end
