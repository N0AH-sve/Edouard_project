defmodule GarageWeb.DocumentsTest do
  use GarageWeb.ConnCase

  import Phoenix.LiveViewTest
  import Garage.AtelierFixtures
  import Garage.ProfilFixtures

  alias Garage.Atelier
  alias Garage.Fichiers
  alias Garage.Stockage

  setup do
    File.mkdir_p!(Stockage.racine())
    reglages_fixture()
    :ok
  end

  defp deposer(vue, formulaire, fichiers) do
    file_input(vue, formulaire, :pdf, fichiers)
  end

  defp pdf_entree(nom, contenu \\ nil) do
    %{
      name: nom,
      content: contenu || Fichiers.pdf(nom),
      type: "application/pdf"
    }
  end

  describe "archivage depuis la fiche client" do
    test "dépose un PDF et le retrouve dans la liste", %{conn: conn} do
      client = client_fixture()
      {:ok, vue, html} = live(conn, ~p"/clients/#{client}")

      assert html =~ "Documents"

      entree = deposer(vue, "#depot-documents-client", [pdf_entree("carte-grise.pdf")])
      assert render_upload(entree, "carte-grise.pdf") =~ "carte-grise.pdf"

      vue |> element("#depot-documents-client") |> render_submit()
      html = render(vue)

      assert html =~ "1 document archivé"
      assert html =~ "carte-grise.pdf"

      assert [document] = Atelier.list_documents({:client, client.id})
      assert document.nom == "carte-grise.pdf"
      assert File.exists?(Stockage.chemin_absolu(document.chemin))
    end

    test "archive plusieurs fichiers d'un coup", %{conn: conn} do
      client = client_fixture()
      {:ok, vue, _html} = live(conn, ~p"/clients/#{client}")

      entree =
        deposer(vue, "#depot-documents-client", [
          pdf_entree("devis.pdf"),
          pdf_entree("facture.pdf")
        ])

      render_upload(entree, "devis.pdf")
      render_upload(entree, "facture.pdf")

      vue |> element("#depot-documents-client") |> render_submit()
      html = render(vue)

      assert html =~ "2 documents archivés"
      assert length(Atelier.list_documents({:client, client.id})) == 2
    end

    test "refuse un fichier qui n'est pas un vrai PDF", %{conn: conn} do
      client = client_fixture()
      {:ok, vue, _html} = live(conn, ~p"/clients/#{client}")

      entree =
        deposer(vue, "#depot-documents-client", [
          pdf_entree("piege.pdf", Fichiers.faux_pdf())
        ])

      render_upload(entree, "piege.pdf")
      vue |> element("#depot-documents-client") |> render_submit()
      html = render(vue)

      assert html =~ "ce n&#39;est pas un vrai PDF"
      assert Atelier.list_documents({:client, client.id}) == []
    end

    test "refuse une extension non autorisée", %{conn: conn} do
      client = client_fixture()
      {:ok, vue, _html} = live(conn, ~p"/clients/#{client}")

      entree =
        deposer(vue, "#depot-documents-client", [
          %{name: "photo.png", content: "pas un pdf", type: "image/png"}
        ])

      # LiveView refuse l'entrée dès la sélection : render_upload renvoie
      # l'erreur au lieu du HTML.
      assert {:error, [[_ref, :not_accepted]]} = render_upload(entree, "photo.png")

      # Et le message est bien rendu pour l'utilisateur.
      assert render(vue) =~ "seuls les fichiers PDF sont acceptés"
    end

    test "supprime un document et son fichier", %{conn: conn} do
      client = client_fixture()
      {:ok, vue, _html} = live(conn, ~p"/clients/#{client}")

      entree = deposer(vue, "#depot-documents-client", [pdf_entree("a-jeter.pdf")])
      render_upload(entree, "a-jeter.pdf")
      vue |> element("#depot-documents-client") |> render_submit()

      assert [document] = Atelier.list_documents({:client, client.id})
      chemin = Stockage.chemin_absolu(document.chemin)
      assert File.exists?(chemin)

      vue
      |> element("button[phx-click=supprimer][phx-value-id='#{document.id}']")
      |> render_click()

      html = render(vue)

      assert html =~ "Document supprimé"
      refute html =~ "a-jeter.pdf"
      assert Atelier.list_documents({:client, client.id}) == []
      refute File.exists?(chemin)
    end

    test "retire un fichier avant de l'envoyer", %{conn: conn} do
      client = client_fixture()
      {:ok, vue, _html} = live(conn, ~p"/clients/#{client}")

      entree = deposer(vue, "#depot-documents-client", [pdf_entree("annule.pdf")])
      html = render_upload(entree, "annule.pdf")
      assert html =~ "annule.pdf"

      vue |> element("button[phx-click=retirer_entree]") |> render_click()

      refute render(vue) =~ "annule.pdf"
      assert Atelier.list_documents({:client, client.id}) == []
    end
  end

  describe "archivage sur un véhicule et une intervention" do
    test "le document est rattaché au véhicule", %{conn: conn} do
      vehicule = vehicule_fixture()
      {:ok, vue, _html} = live(conn, ~p"/vehicules/#{vehicule}")

      entree = deposer(vue, "#depot-documents-vehicule", [pdf_entree("controle.pdf")])
      render_upload(entree, "controle.pdf")
      vue |> element("#depot-documents-vehicule") |> render_submit()

      assert [document] = Atelier.list_documents({:vehicule, vehicule.id})
      assert document.vehicule_id == vehicule.id
      assert is_nil(document.client_id)
    end

    test "le document est rattaché à l'intervention", %{conn: conn} do
      intervention = intervention_fixture()
      {:ok, vue, _html} = live(conn, ~p"/interventions/#{intervention}")

      entree = deposer(vue, "#depot-documents-intervention", [pdf_entree("facture.pdf")])
      render_upload(entree, "facture.pdf")
      vue |> element("#depot-documents-intervention") |> render_submit()

      assert [document] = Atelier.list_documents({:intervention, intervention.id})
      assert document.intervention_id == intervention.id
    end
  end

  describe "consultation des PDF" do
    setup %{conn: conn} do
      client = client_fixture()
      {:ok, vue, _html} = live(conn, ~p"/clients/#{client}")

      entree = file_input(vue, "#depot-documents-client", :pdf, [pdf_entree("facture.pdf")])
      render_upload(entree, "facture.pdf")
      vue |> element("#depot-documents-client") |> render_submit()

      [document] = Atelier.list_documents({:client, client.id})
      %{document: document}
    end

    test "affiche le PDF dans le navigateur", %{conn: conn, document: document} do
      conn = get(conn, ~p"/documents/#{document}")

      assert response_content_type(conn, :pdf) =~ "application/pdf"
      assert [disposition] = get_resp_header(conn, "content-disposition")
      assert disposition == ~s(inline; filename="facture.pdf")
      assert response(conn, 200) =~ "%PDF-"
    end

    test "propose le téléchargement", %{conn: conn, document: document} do
      conn = get(conn, ~p"/documents/#{document}/telecharger")

      assert [disposition] = get_resp_header(conn, "content-disposition")
      assert disposition =~ "attachment"
    end

    test "le PDF n'est pas mis en cache par un intermédiaire", %{conn: conn, document: document} do
      conn = get(conn, ~p"/documents/#{document}")
      assert ["private" <> _] = get_resp_header(conn, "cache-control")
    end

    test "un identifiant inconnu renvoie 404", %{conn: conn} do
      assert_error_sent(404, fn -> get(conn, ~p"/documents/999999") end)
    end

    test "sans profil, les documents ne sont pas servis", %{document: document} do
      Garage.Repo.delete_all(Garage.Profil.Reglages)

      conn = get(Phoenix.ConnTest.build_conn(), ~p"/documents/#{document}")
      assert redirected_to(conn) == "/bienvenue"
    end
  end
end
