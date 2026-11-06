defmodule GarageWeb.PageControllerTest do
  use GarageWeb.ConnCase

  import Garage.ProfilFixtures

  test "sans profil, la racine mène à l'écran de bienvenue", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/bienvenue"
  end

  test "avec un profil, la racine mène au tableau des clients", %{conn: conn} do
    reglages_fixture()

    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/clients"
  end

  test "l'écran de bienvenue disparaît une fois le profil saisi", %{conn: conn} do
    reglages_fixture()

    conn = get(conn, ~p"/bienvenue")
    assert redirected_to(conn) == "/clients"
  end

  test "sans profil, toutes les pages renvoient vers la bienvenue", %{conn: conn} do
    for chemin <- ["/clients", "/vehicules", "/interventions", "/reglages"] do
      assert conn |> get(chemin) |> redirected_to() == "/bienvenue"
    end
  end
end
