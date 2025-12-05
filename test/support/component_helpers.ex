defmodule Moolah.ComponentHelpers do
  @moduledoc """
  Helpers for Phoenix testing components.

  - r2s/1 -> render heex to a string
  - remove_newlines/1 -> remove newlines from string
  - html/1 -> render heex to LazyHTML
  - to_html/1 -> render LazyHTML to HTML
  - find_one/2 -> find one element from html
  - find/2 -> find elements from html
  - count_selector -> count the number of elements from html
  - text/1 -> get text from html
  - text/2 -> get text from html with selector
  - attribute/2 -> get attribute from html
  - attribute/3 -> get attribute from html with selector
  - attributes/1 -> get attributes from html
  - attribute?/2 -> test if html has a given attribute
  - attribute?/3 -> test if html has a given attribute with selector
  - has_class?/2 -> test if html has a given class
  - has_class?/3 -> test if html has a given class with selector
  - value/2 -> get value from html form elements
  - value_for/2 -> get value from html form elements
  - wrap_table/1 -> wrap html in a <table> element
  - normalize_html_input/1 -> normalize html (string/LazyHTML tree/LazyHTML element) input to a string
  - await_update -> check every 10ms if a predicate is true, or timeout after 5 seconds
  - browser/1 -> open browser with html or a view
  """

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  @endpoint TurnWeb.Endpoint

  @type html_input ::
          String.t()
          | list()
          | tuple()
          | %Phoenix.LiveView.Rendered{}

  @doc """
  Shorthand for rendering a component to a string.
  Similar to liveviews test helper t2h

  https://github.com/phoenixframework/phoenix_live_view/blob/main/lib/phoenix_live_view/test/dom.ex#L607

  ## Examples

    iex> assigns = %{}
    iex> r2s(~H"<p>Hello!</p>")
    "<p>Hello!</p>"
  """
  @spec r2s(Phoenix.LiveView.Rendered.t()) :: String.t()
  def r2s(heex) do
    heex
    |> rendered_to_string()
    |> remove_newlines()
  end

  @doc """
  remove newlines from string

  ## Examples

    iex> remove_newlines("hello\\nworld")
    "helloworld"

    iex> remove_newlines("hello\\n\\nworld\\n")
    "helloworld"

    iex> remove_newlines("")
    ""

    iex> remove_newlines("no newlines here")
    "no newlines here"
  """
  @spec remove_newlines(String.t()) :: String.t()
  def remove_newlines(str) do
    str
    |> String.split("\n")
    |> Enum.map_join("", &String.trim(&1))
  end

  @doc """
  Renders the given HEEx template and returns a LazyHTML tree.

  ## Examples

    iex> assigns = %{}
    ...> html(~H"<p>Hello</p>")
    [{"p", [], ["Hello"]}]

    iex> html(~s|<p>Hello</p>|)
    [{"p", [], ["Hello"]}]
  """
  @spec html(html_input()) :: list()
  def html(html) do
    html
    |> normalize_html_input()
    |> LazyHTML.to_tree()
  end

  @doc """
  Converts a LazyHTML tree or node to an HTML fragment string.

  ## Examples

    iex> to_html([{"div", [], ["Hello"]}])
    "<div>Hello</div>"

    iex> to_html({"span", [], ["World"]})
    "<span>World</span>"

    iex> to_html([{"ul", [], [{"li", [], ["Item 1"]}, {"li", [], ["Item 2"]}]}])
    "<ul><li>Item 1</li><li>Item 2</li></ul>"

    iex> to_html({"input", [{"type", "text"}, {"value", "test"}], []})
    ~s|<input type="text" value="test"/>|
  """
  @spec to_html(html_input()) :: String.t()
  def to_html(html) do
    html
    |> normalize_html_input()
    |> LazyHTML.to_html()
  end

  @doc """
  Wrapper around `LazyHTML.query/2` that unwraps the single result.

  Raises if the element isn't found.
  Raises if the element occurs multiple times.

  ## Examples

    iex> find_one(~s|<p>hello</p>|, "p")
    [{"p", [], ["hello"]}]

    iex> find_one(~s|<p>hello</p><p>hello <i>world</i></p>|, "p:not(:has(i))")
    [{"p", [], ["hello"]}]

    iex> find_one(~s|<p>hello</p><p>hello <i>world</i></p>|, "p:has(i)")
    [{"p", [], ["hello ", {"i", [], ["world"]}]}]

    iex> find_one(~s|<p></p><p>hello <i>world</i></p>|, "p:is(:empty)")
    [{"p", [], []}]

    iex> assert_raise RuntimeError, fn -> find_one(~s|<div>hello</div>|, "p") end

    iex> assert_raise RuntimeError, fn -> find_one(~s|<p>hello</p><p>world</p>|, "p") end
  """
  @spec find_one(html_input(), String.t()) :: list()
  @spec find_one(html_input(), String.t()) :: list()
  def find_one(html, selector) do
    result =
      html
      |> normalize_html_input()
      |> LazyHTML.query(selector)

    num_results = Enum.count(result)

    case num_results do
      0 ->
        raise """
        Selector #{inspect(selector)} did not return any results in:

        #{inspect(html, pretty: true)}
        """

      1 ->
        LazyHTML.to_tree(result)

      _multiple ->
        raise """
        Selector #{inspect(selector)} returned multiple results:

        #{inspect(result, pretty: true)}
        """
    end
  end

  @doc """
  Wrapper around `LazyHTML.query/2` that returns all results.

  Raises if the element isn't found.

  ## Examples

    iex> find(~s|<p>hello</p><p>hello</p>|, "p")
    [{"p", [], ["hello"]}, {"p", [], ["hello"]}]

    iex> find(~s|<p>hello</p><p>hello <i>world</i></p>|, "p:not(:has(i))")
    [{"p", [], ["hello"]}]

    iex> find(~s|<p>hello</p><p>hello <i>world</i></p>|, "p:has(i)")
    [{"p", [], ["hello ", {"i", [], ["world"]}]}]

    iex> find(~s|<p></p><p>hello <i>world</i></p>|, "p:is(:empty)")
    [{"p", [], []}]

    iex> assert_raise RuntimeError, fn -> find(~s|<div>hello</div>|, "p") end
  """
  @spec find(html_input(), String.t()) :: list()
  @spec find(html_input(), String.t()) :: list()
  def find(html, selector) do
    result =
      html
      |> normalize_html_input()
      |> LazyHTML.query(selector)

    if Enum.empty?(result) do
      raise """
      Selector #{inspect(selector)} did not return any results in:

      #{inspect(html, pretty: true)}
      """
    else
      LazyHTML.to_tree(result)
    end
  end

  @doc """
  Helper to count the number matches.

  ## Examples

    iex> count_selector("<table><tbody><tr><td></td></tr><tr><td></td></tr></tbody></table>", "tr")
    2

    iex> count_selector("<table><tbody><tr><td></td></tr><tr><td></td></tr></tbody></table>", "td")
    2

    iex> count_selector("<table><tbody><tr><td></td></tr><tr><td></td></tr></tbody></table>", "tbody")
    1

    iex> count_selector("<table><tbody><tr><td></td></tr><tr><td></td></tr></tbody></table>", "thead")
    0
  """
  @spec count_selector(html_input(), String.t()) :: non_neg_integer()
  @spec count_selector(html_input(), String.t()) :: non_neg_integer()
  def count_selector(html, selector) do
    html
    |> normalize_html_input()
    |> LazyHTML.query(selector)
    |> Enum.count()
  end

  @doc """
  Returns the trimmed text nodes from the HTML tree.

  ## Examples

    iex> text("<div><p>Hello!</p></div>")
    "Hello!"

    iex> text("<div>  <p>Hello!</p>  <span>World</span>  </div>")
    "Hello!  World"

    iex> text("<div><p></p></div>")
    ""

    iex> text("<div>Plain text <em>with emphasis</em></div>")
    "Plain text with emphasis"
  """
  @spec text(html_input()) :: String.t()
  @spec text(html_input()) :: String.t()
  def text(html) do
    html
    |> normalize_html_input()
    |> LazyHTML.text()
    |> String.trim()
    |> remove_newlines()
  end

  @doc """
  Returns the trimmed text nodes from the first level of the HTML tree returned
  by the selector.

  Raises if the selector returns zero or more than one result.

  ## Examples

    iex> text("<div><p>One</p><p>Two</p></div>", "p:nth-of-type(2)")
    "Two"

    iex> assert_raise RuntimeError, fn -> text("<div><p>One</p><p>Two</p></div>", "span") end

    iex> assert_raise RuntimeError, fn -> text("<div><p>One</p><p>Two</p></div>", "p") end
  """
  @spec text(html_input(), String.t()) :: String.t()
  @spec text(html_input(), String.t()) :: String.t()
  def text(html, selector) do
    result =
      html
      |> normalize_html_input()
      |> LazyHTML.query(selector)

    num_results = Enum.count(result)

    case num_results do
      1 ->
        result
        |> LazyHTML.text()
        |> String.trim()
        |> remove_newlines()

      0 ->
        raise """
        Selector #{inspect(selector)} returned no results in:

        #{inspect(html, pretty: true)}
        """

      _multiple ->
        raise """
        Selector #{inspect(selector)} returned multiple results in:

        #{inspect(html, pretty: true)}
        """
    end
  end

  @doc """
  Wrapper around `LazyHTML.attribute/2` that unwraps the single attribute.

  Raises if the attribute is found on more than 1 element.

  ## Examples

    iex> attribute(~s|<a href="/">link</a>|, "href")
    "/"

    iex> attribute(~s|<a>link</a>|, "href")
    nil

    iex> attribute(~s|<div title="foo">hello</div>|, "title")
    "foo"

    iex> assert_raise RuntimeError, fn ->
    ...>  attribute(~s|<a href="/1">link</a><a href="/2">link</a>|, "href")
    ...> end
  """

  @spec attribute(html_input(), String.t()) :: String.t() | nil
  @spec attribute(html_input(), String.t()) :: String.t() | nil
  def attribute(html, attribute_name) do
    attribute =
      html
      |> normalize_html_input()
      |> LazyHTML.attribute(attribute_name)

    unwrap_single_value(attribute, attribute_name)
  end

  @doc """
  Wrapper around `LazyHTML.attribute` that unwraps the single attribute (with selector).

  Raises if the selector returns zero or more than one result.

  ## Examples

    iex> attribute(~s|<p><a href="/1">link</a><a href="/2">link</a></p>|, "a:nth-of-type(2)", "href")
    "/2"

    iex> attribute(~s|<p><a href="/1">link</a><a href="/2">link</a></p>|, "a:nth-of-type(2)", "title")
    nil

    iex> attribute(~s|<p><a href="/1">link</a><a href="/2">link</a></p>|, "a:nth-of-type(3)", "href")
    nil
  """
  @spec attribute(html_input(), String.t(), String.t()) :: String.t() | nil
  @spec attribute(html_input(), String.t(), String.t()) :: String.t() | nil
  def attribute(html, selector, attribute_name) do
    attribute =
      html
      |> normalize_html_input()
      |> LazyHTML.query(selector)
      |> LazyHTML.attribute(attribute_name)

    unwrap_single_value(attribute, attribute_name)
  end

  @doc """
  Wrapper around `LazyHTML.attributes/1` that unwraps the single attribute.
  Returns a map instead of a list of tuples for easier access.

  Raises if the attribute is found on more than 1 element.

  ## Examples

    iex> attributes(~s|<a href="/" title="foo">link</a>|)
    %{"href" => "/", "title" => "foo"}

    iex> attributes(~s|<div title="foo">hello</div>|)
    %{"title" => "foo"}

    iex> attributes(~s|<a>link</a>|)
    %{}

    iex> attributes("")
    nil

    iex> assert_raise RuntimeError, fn ->
    ...>  attributes(~s|<a href="/1">link</a><a href="/2">link</a>|)
    ...> end
  """
  @spec attributes(html_input()) :: map() | nil
  @spec attributes(html_input()) :: map() | nil
  def attributes(html) do
    attributes =
      html
      |> normalize_html_input()
      |> LazyHTML.attributes()

    case attributes do
      [value] -> Map.new(value)
      _ -> unwrap_single_value(attributes, "attributes")
    end
  end

  defp unwrap_single_value([value], _label), do: value
  defp unwrap_single_value([], _label), do: nil

  defp unwrap_single_value(multiple, label) do
    raise """
    Multiple elements returned for #{label}:
    #{inspect(multiple)}
    """
  end

  @doc """
  Wrapper around `LazyHTML.attribute/2` that checks if the attribute exists.

  ## Examples

    iex> attribute?(~s|<a href="/">link</a>|, "href")
    true

    iex> attribute?(~s|<a>link</a>|, "href")
    false

    iex> attribute?(~s|<input type="checkbox" checked>|, "checked")
    true

    iex> attribute?(~s|<input type="text" value="">|, "value")
    true

    iex> attribute?(~s|<div class="container">content</div>|, "id")
    false
  """
  @spec attribute?(html_input(), String.t()) :: boolean()
  def attribute?(html, attribute_name) do
    html
    |> normalize_html_input()
    |> LazyHTML.attribute(attribute_name)
    |> Enum.any?()
  end

  @doc """
  Wrapper around `LazyHTML.attribute` that checks if the attribute exists (with selector).

  ## Examples

    iex> attribute?(~s|<p><a href="/">link</a></p>|, "a", "href")
    true

    iex> attribute?(~s|<p><a>link</a><p>|, "a", "href")
    false

    iex> attribute?(~s|<p><input type="checkbox" checked></p>|, "input", "checked")
    true

    iex> attribute?(~s|<p><input type="text" value="">|, "input", "value")
    true

    iex> attribute?(~s|<div><div class="container">content</div>|, "div", "id")
    false
  """
  @spec attribute?(html_input(), String.t(), String.t()) :: boolean()
  def attribute?(html, selector, attribute_name) do
    html
    |> normalize_html_input()
    |> LazyHTML.query(selector)
    |> LazyHTML.attribute(attribute_name)
    |> Enum.any?()
  end

  @doc """
  Wrapper around `LazyHTML.attribute/2` that checks if an element has a class.

  ## Examples

    iex> has_class?(~s|<a href="/" class="bg-red">link</a>|, "bg-red")
    true

    iex> has_class?(~s|<a href="/" class="border-blue bg-red underline">link</a>|, "bg-red")
    true

    iex> has_class?(~s|<a class="bg-blue">link</a>|, "bg-red")
    false

    iex> has_class?(~s|<a>link</a>|, "bg-red")
    false

    iex> has_class?(~s|<a><b class="bg-red">link</b></a>|, "bg-red")
    false
  """
  @spec has_class?(html_input(), String.t()) :: boolean()
  @spec has_class?(html_input(), String.t()) :: boolean()
  def has_class?(html, class_name) do
    html =
      html
      |> normalize_html_input()
      |> LazyHTML.to_tree()

    case attribute(html, "class") do
      str when is_binary(str) ->
        str
        |> String.split(" ")
        |> Enum.member?(class_name)

      _ ->
        false
    end
  end

  @doc """
  Wrapper around `LazyHTML.attribute` that checks if an element has a class (with selector).

  ## Examples

    iex> has_class?(~s|<p><a href="/" class="bg-red">link</a></p>|, "a", "bg-red")
    true

    iex> has_class?(~s|<p><a href="/" class="border-blue bg-red underline">link</a></p>|, "a", "bg-red")
    true

    iex> has_class?(~s|<p><a class="bg-blue">link</a></p>|, "a", "bg-red")
    false

    iex> has_class?(~s|<p><a>link</a></p>|, "a", "bg-red")
    false

    iex> has_class?(~s|<p><a><b class="bg-red">link</b></a></p>|, "a", "bg-red")
    false
  """
  @spec has_class?(html_input(), String.t(), String.t()) :: boolean()
  def has_class?(html, selector, class_name) do
    html =
      html
      |> normalize_html_input()
      |> LazyHTML.query(selector)
      |> LazyHTML.to_tree()

    case attribute(html, "class") do
      str when is_binary(str) ->
        str
        |> String.split(" ")
        |> Enum.member?(class_name)

      _ ->
        false
    end
  end

  @doc """
  Get the value of a form input element
  this can be a select, textarea, input, radio or checkbox.

  Be sure to add :checked to the selector for radio and checkbox elements,
  because otherwise it will raise an error that multiple elements are found.

  ## Examples

    iex> value(~s|<div />|, ~s|input[type="text"]|)
    nil

    iex> value(~s|<input type="text" value="hello">|, ~s|input[type="text"]|)
    "hello"

    iex> value(~s|<input type="text">|, ~s|input[type="text"]|)
    nil

    iex> value(~s|<textarea>hello</textarea>|, "textarea")
    "hello"

    iex> value(~s|<textarea></textarea>|, "textarea")
    nil

    iex> value(~s|<select><option value="1" selected>One</option></select>|, "select")
    "1"

    iex> value(~s|<select><option value="1">One</option></select>|, "select")
    nil

    iex> value(~s|<input type="checkbox" value="1" checked />|, ~s|input[type="checkbox"]:checked|)
    "1"

    iex> value(~s|<input type="checkbox" value="1" />|, ~s|input[type="checkbox"]:checked|)
    nil

    iex> value(~s|<input type="radio" value="1" checked />|, ~s|input[type="radio"]:checked|)
    "1"

    iex> value(~s|<input type="radio" value="1" />|, ~s|input[type="radio"]:checked|)
    nil
  """
  @spec value(html_input(), String.t()) :: String.t() | nil
  def value(html, selector) do
    element =
      html
      |> normalize_html_input()
      |> LazyHTML.query(selector)

    tag =
      element
      |> LazyHTML.tag()
      |> List.first()

    case tag do
      "select" -> value_for("select", element)
      "textarea" -> value_for("textarea", element)
      "input" -> value_for("input", element)
      "radio" -> value_for("radio", element)
      "checkbox" -> value_for("checkbox", element)
      _ -> nil
    end
  end

  defp value_for("select", element) do
    value =
      element
      |> LazyHTML.query("option[selected]")
      |> LazyHTML.attribute("value")

    case value do
      [_] -> List.first(value)
      _ -> nil
    end
  end

  defp value_for("input", element) do
    element
    |> LazyHTML.attribute("value")
    |> List.first()
  end

  defp value_for("textarea", element) do
    case LazyHTML.text(element) do
      "" -> nil
      value -> value
    end
  end

  defp value_for("radio", element) do
    LazyHTML.attribute(element, "value")
  end

  defp value_for("checkbox", element) do
    LazyHTML.attribute(element, "value")
  end

  @doc """
  Await an update by checking a predicate every 100ms until it returns true
  or the timeout is reached.
  It is very similar to render_async, but it allows you to check for a specific
  condition instead of just waiting for the view to be rendered. This is useful
  when the LiveView process is not aware of the state change you are waiting for.

  ## Examples

    iex> await_update(fn -> true end)
    :ok

    iex> await_update(fn -> false end, 500)
    :timeout
  """
  @spec await_update((-> boolean), non_neg_integer()) :: :ok | :timeout
  def await_update(await_predicate, timeout \\ 5000) do
    cond do
      await_predicate.() ->
        :ok

      timeout < 0 ->
        :timeout

      true ->
        :timer.sleep(100)
        await_update(await_predicate, timeout - 100)
    end
  end

  @doc """
  Counts the occurrences of a substring in a given string.

  ## Examples

    iex> count_text("hello world", "hello")
    1

    iex> count_text("hello hello hello", "hello")
    3

    iex> count_text("no matches here", "test")
    0

    iex> count_text("case CASE case", "case")
    2

    iex> count_text("overlapping hellohello", "hello")
    2

    iex> count_text("", "hello")
    0

    iex> count_text("hello", "")
    0

    iex> count_text(nil, "hello")
    0
  """
  @spec count_text(String.t() | nil, String.t()) :: integer()
  def count_text(_text, ""), do: 0
  def count_text(nil, _substring), do: 0

  def count_text(text, substring) when is_binary(text) and is_binary(substring) do
    substring
    |> Regex.escape()
    |> Regex.compile!()
    |> Regex.scan(text)
    |> length()
  end

  @doc """
  LazyHTML needs a correct table to be able to work with fragments.
  This helper wraps the given HTML in a table tag. We can't use the
  normalize_html helper, because this is technically an invalid HTML snippet.

  ## Examples

    iex> wrap_table(~s|<tr><td>hello</td></tr>|)
    "<table><tr><td>hello</td></tr></table>"

    iex> wrap_table("")
    "<table></table>"

    iex> wrap_table([{"tr", [], [{"td", [], ["test"]}]}])
    "<table><tr><td>test</td></tr></table>"

    iex> assert_raise ArgumentError, "Expected a binary string, got: nil", fn -> wrap_table(nil) end
  """
  def wrap_table(html) when is_binary(html) do
    "<table>" <> html <> "</table>"
  end

  def wrap_table(html) when is_list(html) do
    html
    |> LazyHTML.from_tree()
    |> LazyHTML.to_html()
    |> wrap_table()
  end

  def wrap_table(html) do
    raise ArgumentError, "Expected a binary string, got: #{inspect(html)}"
  end

  @doc """
  Renders the given HEEx template and returns the tagname of the root element.

  ## Examples

    iex> assigns = %{}
    ...> tag_name(~H"<p>Hello</p>")
    "p"

    iex> tag_name(~s|<a>Hello</a><b>Hello</b>|)
    "a"
  """
  @spec tag_name(html_input()) :: list()
  def tag_name(html) do
    html
    |> normalize_html_input()
    |> LazyHTML.tag()
    |> List.first()
  end

  @doc """
  Normalizes various types of HTML input into a parsed LazyHTML document.

  Accepts:
    - A raw HTML string
    - A LazyHTML tree list
    - A single LazyHTML tree element (tuple)

  ## Examples

    iex> alias LazyHTML
    iex> html = "<div>Hello</div>"
    ...> normalize_html_input(html) |> LazyHTML.to_tree()
    [{"div", [], ["Hello"]}]

    iex> assigns = %{}
    ...> heex = ~H"<div>Hello</div>"
    ...> normalize_html_input(heex) |> LazyHTML.to_tree()
    [{"div", [], ["Hello"]}]

    iex> tree = [{"div", [], ["World"]}]
    ...> normalize_html_input(tree) |> LazyHTML.to_tree()
    [{"div", [], ["World"]}]

    iex> node = {"p", [], ["Text"]}
    ...> normalize_html_input(node) |> LazyHTML.to_tree()
    [{"p", [], ["Text"]}]
  """
  @spec normalize_html_input(html_input()) :: any()
  def normalize_html_input(html) when is_binary(html) do
    html
    |> LazyHTML.from_fragment()
  end

  def normalize_html_input(%Phoenix.LiveView.Rendered{} = heex) do
    heex
    |> rendered_to_string()
    |> LazyHTML.from_fragment()
  end

  def normalize_html_input(tree) when is_list(tree) do
    tree
    |> LazyHTML.from_tree()
    |> LazyHTML.to_html()
    |> LazyHTML.from_fragment()
  end

  def normalize_html_input(tree_element) do
    [tree_element]
    |> LazyHTML.from_tree()
    |> LazyHTML.to_html()
    |> LazyHTML.from_fragment()
  end

  @doc """
  Helper on top of Phoenix.LiveViewTest.open_browser to support opening
  HTML in the browser. This is helpful when debugging rendered html
  without a view.

  https://github.com/phoenixframework/phoenix_live_view/blob/fbed65d4f49e5de1d130ca30050ffab79688657c/lib/phoenix_live_view/test/live_view_test.ex#L1522

  ## Examples

    # Opens browser with HTML content
    # browser("<div>test</div>")

    # Opens browser with LiveView
    # browser(view)
  """

  def browser(html) when is_binary(html) do
    {:ok, view, _html} =
      live_isolated_component(Turn.ComponentHelpers.TestComponent, assigns: %{html: html})

    Phoenix.LiveViewTest.open_browser(view)
  end

  def browser(view_or_element) do
    Phoenix.LiveViewTest.open_browser(view_or_element)
  end
end

defmodule Turn.ComponentHelpers.TestComponent do
  @moduledoc """
  Helper LiveComponent to test rendered HTML.
  """

  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <html>
      <head>
        <link rel="stylesheet" href="/assets/app.css" />
      </head>
      <body>{Phoenix.HTML.raw(@html)}</body>
    </html>
    """
  end
end
