defmodule GarageWeb.PageController do
  use GarageWeb, :controller

  @doc """
  La racine n'affiche rien : l'écran principal est le tableau des clients.
  """
  def home(conn, _params), do: redirect(conn, to: ~p"/clients")
end
