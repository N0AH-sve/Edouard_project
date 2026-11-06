defmodule GarageWeb.VehiculeLiveTest do
  use GarageWeb.ConnCase

  import Phoenix.LiveViewTest
  import Garage.AtelierFixtures
  import Garage.ProfilFixtures

  setup do
    %{reglages: reglages_fixture()}
  end

  describe "liste des véhicules" do
    test "affiche les véhicules et leur propriétaire", %{conn: conn} do
      client = client_fixture(nom: "Bernard", prenom: "Martine")
      vehicule_fixture(immatriculation: "AB-123-CD", marque: "Renault", client_id: client.id)

      {:ok, _vue, html} = live(conn, ~p"/vehicules")

      assert html =~ "Tous les véhicules"
      assert html =~ "AB-123-CD"
      assert html =~ "Renault"
      assert html =~ "Bernard Martine"
    end

    test "cherche par plaque sans tirets", %{conn: conn} do
      vehicule_fixture(immatriculation: "AB-123-CD")
      vehicule_fixture(immatriculation: "ZZ-999-ZZ")

      {:ok, vue, _html} = live(conn, ~p"/vehicules")
      html = vue |> form("#formulaire-recherche", %{"q" => "ab123cd"}) |> render_change()

      assert html =~ "AB-123-CD"
      refute html =~ "ZZ-999-ZZ"
    end

    test "l'onglet « contrôle technique » ne montre que les échéances proches", %{conn: conn} do
      vehicule_fixture(
        immatriculation: "AA-111-AA",
        date_prochain_ct: Date.add(Date.utc_today(), 10)
      )

      vehicule_fixture(
        immatriculation: "BB-222-BB",
        date_prochain_ct: Date.add(Date.utc_today(), 400)
      )

      {:ok, _vue, html} = live(conn, ~p"/vehicules?filtre=ct")

      assert html =~ "AA-111-AA"
      refute html =~ "BB-222-BB"
    end

    test "signale un contrôle technique échu", %{conn: conn} do
      vehicule_fixture(date_prochain_ct: Date.add(Date.utc_today(), -5))

      {:ok, _vue, html} = live(conn, ~p"/vehicules")
      assert html =~ "échu"
    end
  end

  describe "création" do
    test "normalise l'immatriculation saisie", %{conn: conn} do
      client = client_fixture()

      {:ok, vue, _html} = live(conn, ~p"/vehicules/nouveau")

      assert {:error, {:live_redirect, %{to: destination}}} =
               vue
               |> form("#formulaire-vehicule",
                 vehicule: %{
                   immatriculation: "ab 123 cd",
                   marque: "Peugeot",
                   client_id: client.id
                 }
               )
               |> render_submit()

      {:ok, _vue, html} = live(conn, destination)
      assert html =~ "AB-123-CD"
    end

    test "refuse une plaque déjà utilisée", %{conn: conn} do
      vehicule_fixture(immatriculation: "AB-123-CD")
      client = client_fixture()

      {:ok, vue, _html} = live(conn, ~p"/vehicules/nouveau")

      html =
        vue
        |> form("#formulaire-vehicule",
          vehicule: %{immatriculation: "AB-123-CD", client_id: client.id}
        )
        |> render_submit()

      assert html =~ "un véhicule porte déjà cette immatriculation"
    end

    test "arrivé depuis une fiche client, le propriétaire est pré-rempli", %{conn: conn} do
      client = client_fixture(nom: "Prérempli")

      {:ok, _vue, html} = live(conn, ~p"/vehicules/nouveau?client=#{client.id}")

      assert html =~ ~s(selected="" value="#{client.id}">Prérempli)
    end
  end

  describe "fiche véhicule" do
    test "montre l'historique et le total facturé", %{conn: conn} do
      vehicule = vehicule_fixture(immatriculation: "AB-123-CD")

      intervention_fixture(
        vehicule_id: vehicule.id,
        description: "Vidange",
        montant_euros: "120,00",
        statut: :paye
      )

      # Un devis n'est pas du chiffre d'affaires : il ne doit pas compter.
      intervention_fixture(
        vehicule_id: vehicule.id,
        description: "Carrosserie",
        montant_euros: "900,00",
        statut: :devis
      )

      {:ok, _vue, html} = live(conn, ~p"/vehicules/#{vehicule}")

      assert html =~ "Vidange"
      assert html =~ "Carrosserie"
      assert html =~ "Total facturé"
      assert html =~ "120,00"
      refute html =~ "1 020,00"
    end

    test "le dit quand il n'y a pas d'historique", %{conn: conn} do
      vehicule = vehicule_fixture()
      {:ok, _vue, html} = live(conn, ~p"/vehicules/#{vehicule}")

      assert html =~ "Aucune intervention enregistrée"
    end
  end
end
