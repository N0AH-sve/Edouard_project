defmodule GarageWeb.InterventionLiveTest do
  use GarageWeb.ConnCase

  import Phoenix.LiveViewTest
  import Garage.AtelierFixtures
  import Garage.ProfilFixtures

  setup do
    %{reglages: reglages_fixture()}
  end

  describe "liste des interventions" do
    test "affiche les interventions en français", %{conn: conn} do
      vehicule = vehicule_fixture(immatriculation: "AB-123-CD")
      intervention_fixture(vehicule_id: vehicule.id, type: :vidange, montant_euros: "124,50")

      {:ok, _vue, html} = live(conn, ~p"/interventions")

      assert html =~ "Toutes"
      assert html =~ "AB-123-CD"
      assert html =~ "Vidange"
      assert html =~ "124,50"
    end

    test "filtre par statut via l'onglet", %{conn: conn} do
      vehicule = vehicule_fixture()
      intervention_fixture(vehicule_id: vehicule.id, description: "Encours", statut: :en_cours)
      intervention_fixture(vehicule_id: vehicule.id, description: "Payée", statut: :paye)

      {:ok, _vue, html} = live(conn, ~p"/interventions?statut=en_cours")

      assert html =~ "Encours"
      refute html =~ "Payée"
    end

    test "un statut inconnu dans l'URL est ignoré", %{conn: conn} do
      vehicule = vehicule_fixture()
      intervention_fixture(vehicule_id: vehicule.id, description: "Visible")

      {:ok, _vue, html} = live(conn, ~p"/interventions?statut=nimportequoi")

      assert html =~ "Visible"
    end

    test "affiche le total encaissé", %{conn: conn} do
      vehicule = vehicule_fixture()
      intervention_fixture(vehicule_id: vehicule.id, montant_euros: "100,00", statut: :paye)

      {:ok, _vue, html} = live(conn, ~p"/interventions")

      assert html =~ "Encaissé"
      assert html =~ "100,00"
    end

    test "marque les interventions sélectionnées comme payées", %{conn: conn} do
      intervention = intervention_fixture(statut: :facture)

      {:ok, vue, _html} = live(conn, ~p"/interventions")
      vue |> element("input[phx-value-id='#{intervention.id}']") |> render_click()
      html = vue |> element("button[phx-click=marquer_payees]") |> render_click()

      assert html =~ "1 intervention marquée payée"
      assert Garage.Atelier.get_intervention!(intervention.id).statut == :paye
    end
  end

  describe "création" do
    test "convertit le montant saisi en euros", %{conn: conn} do
      vehicule = vehicule_fixture()

      {:ok, vue, _html} = live(conn, ~p"/interventions/nouvelle")

      assert {:error, {:live_redirect, %{to: destination}}} =
               vue
               |> form("#formulaire-intervention",
                 intervention: %{
                   vehicule_id: vehicule.id,
                   date: Date.to_iso8601(Date.utc_today()),
                   type: "revision",
                   statut: "devis",
                   description: "Essai",
                   montant_euros: "1 234,56"
                 }
               )
               |> render_submit()

      {:ok, _vue, html} = live(conn, destination)
      # Espace insécable : un montant ne doit pas se couper en fin de ligne.
      assert html =~ "1\u00A0234,56"
    end

    test "refuse une date future", %{conn: conn} do
      vehicule = vehicule_fixture()
      demain = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()

      {:ok, vue, _html} = live(conn, ~p"/interventions/nouvelle")

      html =
        vue
        |> form("#formulaire-intervention",
          intervention: %{
            vehicule_id: vehicule.id,
            date: demain,
            type: "revision",
            statut: "devis"
          }
        )
        |> render_submit()

      assert html =~ "ne peut pas être datée dans le futur"
    end

    test "refuse un montant illisible", %{conn: conn} do
      vehicule = vehicule_fixture()

      {:ok, vue, _html} = live(conn, ~p"/interventions/nouvelle")

      html =
        vue
        |> form("#formulaire-intervention",
          intervention: %{
            vehicule_id: vehicule.id,
            date: Date.to_iso8601(Date.utc_today()),
            type: "revision",
            statut: "devis",
            montant_euros: "beaucoup"
          }
        )
        |> render_submit()

      assert html =~ "montant invalide"
    end
  end

  describe "modification" do
    test "le montant est pré-rempli en euros", %{conn: conn} do
      intervention = intervention_fixture(montant_euros: "249,90")

      {:ok, _vue, html} = live(conn, ~p"/interventions/#{intervention}/modifier")

      assert html =~ ~s(value="249,90")
    end
  end

  describe "détail" do
    test "montre le véhicule, le client et le montant", %{conn: conn} do
      client = client_fixture(nom: "Dubois", prenom: "Karim")
      vehicule = vehicule_fixture(immatriculation: "IJ-789-KL", client_id: client.id)

      intervention =
        intervention_fixture(
          vehicule_id: vehicule.id,
          description: "Vanne EGR",
          montant_euros: "487,30"
        )

      {:ok, _vue, html} = live(conn, ~p"/interventions/#{intervention}")

      assert html =~ "IJ-789-KL"
      assert html =~ "Dubois Karim"
      assert html =~ "Vanne EGR"
      assert html =~ "487,30"
    end
  end
end
