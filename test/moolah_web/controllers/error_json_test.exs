defmodule MoolahWeb.ErrorJSONTest do
  use MoolahWeb.ConnCase, async: true

  test "renders 404" do
    assert MoolahWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert MoolahWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
