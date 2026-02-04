defmodule MoolahWeb.LiveUserAuthTest do
  @moduledoc """
  Tests for the MoolahWeb.LiveUserAuth module.
  """
  use MoolahWeb.ConnCase, async: true

  alias Moolah.Accounts.User
  alias MoolahWeb.LiveUserAuth

  describe "on_mount :live_user_optional" do
    test "continues when user is present" do
      user = %User{id: "test-user-id", email: "test@example.com"}

      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}, current_user: user}
      }

      assert {:cont, socket} = LiveUserAuth.on_mount(:live_user_optional, %{}, %{}, socket)
      assert socket.assigns.current_user == user
    end

    test "assigns nil current_user when user is not present" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}}
      }

      assert {:cont, socket} = LiveUserAuth.on_mount(:live_user_optional, %{}, %{}, socket)
      assert socket.assigns.current_user == nil
    end
  end

  describe "on_mount :live_user_required" do
    test "continues when user is present" do
      user = %User{id: "test-user-id", email: "test@example.com"}

      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}, current_user: user}
      }

      assert {:cont, socket} = LiveUserAuth.on_mount(:live_user_required, %{}, %{}, socket)
      assert socket.assigns.current_user == user
    end

    test "redirects to sign-in when user is not present" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}}
      }

      assert {:halt, socket} = LiveUserAuth.on_mount(:live_user_required, %{}, %{}, socket)
      # Verify redirect was set
      assert socket.redirected
    end
  end

  describe "on_mount :live_no_user" do
    test "redirects to home when user is present" do
      user = %User{id: "test-user-id", email: "test@example.com"}

      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}, current_user: user}
      }

      assert {:halt, socket} = LiveUserAuth.on_mount(:live_no_user, %{}, %{}, socket)
      # Verify redirect was set
      assert socket.redirected
    end

    test "continues with nil current_user when user is not present" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}}
      }

      assert {:cont, socket} = LiveUserAuth.on_mount(:live_no_user, %{}, %{}, socket)
      assert socket.assigns.current_user == nil
    end
  end
end
