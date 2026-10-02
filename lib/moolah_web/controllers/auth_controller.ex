defmodule MoolahWeb.AuthController do
  use MoolahWeb, :controller
  use AshAuthentication.Phoenix.Controller

  alias Ash.Resource.Record
  alias Plug.Conn

  @doc "Completes sign-in and redirects to the requested page."
  @spec success(Conn.t(), {atom(), atom()}, Record.t(), String.t() | nil) ::
          Conn.t()
  def success(conn, activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    message =
      case activity do
        {:confirm_new_user, :confirm} -> "Your email address has now been confirmed"
        {:password, :reset} -> "Your password has successfully been reset"
        _ -> "You are now signed in"
      end

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    # If your resource has a different name, update the assign name here (i.e :current_admin)
    |> assign(:current_user, user)
    |> put_flash(:info, message)
    |> redirect(to: return_to)
  end

  @doc "Reports an authentication failure and returns to the sign-in page."
  @spec failure(Conn.t(), {atom(), atom()}, term()) :: Conn.t()
  def failure(conn, activity, reason) do
    message =
      case {activity, reason} do
        {_,
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %Ash.Error.Forbidden{
             errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
           }
         }} ->
          """
          You have already signed in another way, but have not confirmed your account.
          You can confirm your account using the link we sent to you, or by resetting your password.
          """

        _ ->
          "Incorrect email or password"
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/sign-in")
  end

  @doc "Clears the user session and redirects after sign-out."
  @spec sign_out(Conn.t(), map()) :: Conn.t()
  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session(:moolah)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: return_to)
  end
end
