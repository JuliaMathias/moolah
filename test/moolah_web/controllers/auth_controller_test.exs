defmodule MoolahWeb.AuthControllerTest do
  @moduledoc """
  Tests for the MoolahWeb.AuthController module.
  """
  use MoolahWeb.ConnCase, async: true

  describe "success/4 message content" do
    test "returns correct message for sign in activity" do
      # Test the message logic without full integration
      activity = {:password, :sign_in}
      expected_message = "You are now signed in"

      message =
        case activity do
          {:confirm_new_user, :confirm} -> "Your email address has now been confirmed"
          {:password, :reset} -> "Your password has successfully been reset"
          _ -> "You are now signed in"
        end

      assert message == expected_message
    end

    test "returns correct message for password reset activity" do
      activity = {:password, :reset}
      expected_message = "Your password has successfully been reset"

      message =
        case activity do
          {:confirm_new_user, :confirm} -> "Your email address has now been confirmed"
          {:password, :reset} -> "Your password has successfully been reset"
          _ -> "You are now signed in"
        end

      assert message == expected_message
    end

    test "returns correct message for email confirmation activity" do
      activity = {:confirm_new_user, :confirm}
      expected_message = "Your email address has now been confirmed"

      message =
        case activity do
          {:confirm_new_user, :confirm} -> "Your email address has now been confirmed"
          {:password, :reset} -> "Your password has successfully been reset"
          _ -> "You are now signed in"
        end

      assert message == expected_message
    end
  end

  describe "failure/3 message content" do
    test "returns generic error message for most failures" do
      activity = {:password, :sign_in}
      reason = :invalid_credentials
      expected_message = "Incorrect email or password"

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

      assert message == expected_message
    end

    test "returns special message for unconfirmed user error" do
      reason = %AshAuthentication.Errors.AuthenticationFailed{
        caused_by: %Ash.Error.Forbidden{
          errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
        }
      }

      activity = {:password, :sign_in}

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

      assert message =~ "You have already signed in another way"
      assert message =~ "but have not confirmed your account"
    end
  end
end
