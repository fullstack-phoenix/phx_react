defmodule <%= inspect controller_module %> do
  use <%= inspect context.web_module %>, :controller

  alias <%= inspect context.web_module %>.ReactController

  def index(conn, params) do
    ReactController.render_named_page(conn, "<%= page_keys.index %>", params)
  end

  def new(conn, params) do
    ReactController.render_named_page(
      conn,
      "<%= page_keys.form %>",
      Map.put(params, "mode", "new")
    )
  end

  def show(conn, params) do
    ReactController.render_named_page(conn, "<%= page_keys.show %>", params)
  end

  def edit(conn, params) do
    ReactController.render_named_page(
      conn,
      "<%= page_keys.form %>",
      Map.put(params, "mode", "edit")
    )
  end
end
