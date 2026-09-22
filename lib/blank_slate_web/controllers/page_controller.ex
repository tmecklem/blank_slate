defmodule BlankSlateWeb.PageController do
  use BlankSlateWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
