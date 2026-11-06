defmodule GarageWeb.ClientLiveTest do
  use GarageWeb.ConnCase

  import Phoenix.LiveViewTest
  import Garage.AtelierFixtures
  import Garage.ProfilFixtures

  setup do
    # Tous ces écrans sont derrière la porte d'entrée : sans profil,
    # l'application renvoie vers l'écran de bienvenue.
    %{reglages: reglages_fixture()}
  end

  describe "liste des clients" do
    test "affiche les clients en français", %{conn: conn} do
      client_fixture(nom: "Bernard", prenom: "Martine")

      {:ok, _vue, html} = live(conn, ~p"/clients")

      assert html =~ "Tous les clients"
      assert html =~ "Bernard Martine"
      assert html =~ "Nouveau client"
      refute html =~ "Listing Clients"
    end

    test "affiche un message quand il n'y a aucun client", %{conn: conn} do
      {:ok, _vue, html} = live(conn, ~p"/clients")
      assert html =~ "Aucun client pour le moment"
    end

    test "la recherche filtre la liste", %{conn: conn} do
      client_fixture(nom: "Bernard", prenom: "Martine")
      client_fixture(nom: "Dubois", prenom: "Karim")

      {:ok, vue, _html} = live(conn, ~p"/clients")

      html = vue |> form("form[phx-change=rechercher]", %{"q" => "bernard"}) |> render_change()

      assert html =~ "Bernard"
      refute html =~ "Dubois"
    end

    test "la recherche ignore les accents", %{conn: conn} do
      client_fixture(nom: "Benoît", prenom: "Céline", email: nil)

      {:ok, vue, _html} = live(conn, ~p"/clients")
      html = vue |> form("form[phx-change=rechercher]", %{"q" => "benoit"}) |> render_change()

      assert html =~ "Benoît"
    end

    test "une recherche sans résultat le dit", %{conn: conn} do
      client_fixture(nom: "Bernard")

      {:ok, vue, _html} = live(conn, ~p"/clients")

      html =
        vue |> form("form[phx-change=rechercher]", %{"q" => "zzintrouvable"}) |> render_change()

      assert html =~ "Aucun résultat"
    end
  end

  describe "sélection multiple" do
    test "la barre d'actions apparaît dès qu'une ligne est cochée", %{conn: conn} do
      client = client_fixture()

      {:ok, vue, html} = live(conn, ~p"/clients")
      refute html =~ "élément sélectionné"

      html = vue |> element("input[phx-value-id='#{client.id}']") |> render_click()

      assert html =~ "1"
      assert html =~ "élément sélectionné"
      assert html =~ "Supprimer"
    end

    test "supprime les clients cochés", %{conn: conn} do
      client = client_fixture(nom: "Jetable")

      {:ok, vue, _html} = live(conn, ~p"/clients")
      vue |> element("input[phx-value-id='#{client.id}']") |> render_click()
      html = vue |> element("button[phx-click=supprimer_selection]") |> render_click()

      assert html =~ "1 client supprimé"
      refute html =~ "Jetable"
    end

    test "refuse de supprimer un client qui a un véhicule", %{conn: conn} do
      vehicule = vehicule_fixture()
      client_id = vehicule.client_id

      {:ok, vue, _html} = live(conn, ~p"/clients")
      vue |> element("input[phx-value-id='#{client_id}']") |> render_click()
      html = vue |> element("button[phx-click=supprimer_selection]") |> render_click()

      assert html =~ "supprimez d&#39;abord leurs véhicules"
    end
  end

  describe "création" do
    test "crée un client et arrive sur sa fiche", %{conn: conn} do
      {:ok, vue, _html} = live(conn, ~p"/clients/nouveau")

      assert {:error, {:live_redirect, %{to: destination}}} =
               vue
               |> form("#formulaire-client",
                 client: %{nom: "Nouveau", prenom: "Client", telephone: "0601020304"}
               )
               |> render_submit()

      assert destination =~ ~r{^/clients/\d+$}

      {:ok, _vue, html} = live(conn, destination)
      assert html =~ "Nouveau Client"
    end

    test "signale un nom manquant", %{conn: conn} do
      {:ok, vue, _html} = live(conn, ~p"/clients/nouveau")

      html = vue |> form("#formulaire-client", client: %{nom: ""}) |> render_change()
      assert html =~ "le nom est obligatoire"
    end
  end

  describe "fiche client" do
    test "montre les véhicules et leur historique", %{conn: conn} do
      vehicule = vehicule_fixture(immatriculation: "AB-123-CD", marque: "Renault")

      intervention_fixture(
        vehicule_id: vehicule.id,
        description: "Changement de plaquettes",
        montant_euros: "249,90"
      )

      {:ok, _vue, html} = live(conn, ~p"/clients/#{vehicule.client_id}")

      assert html =~ "AB-123-CD"
      assert html =~ "Renault"
      assert html =~ "Changement de plaquettes"
      assert html =~ "249,90"
    end

    test "le dit quand le client n'a pas de véhicule", %{conn: conn} do
      client = client_fixture()
      {:ok, _vue, html} = live(conn, ~p"/clients/#{client}")

      assert html =~ "Aucun véhicule enregistré"
    end
  end
end
