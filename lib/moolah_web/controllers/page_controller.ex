defmodule MoolahWeb.PageController do
  use MoolahWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
