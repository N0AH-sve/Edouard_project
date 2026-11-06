defmodule GarageWeb.DocumentController do
  @moduledoc """
  Sert les PDF archivés.

  Le chemin du fichier n'est jamais pris dans la requête : seul un
  identifiant l'est, et le chemin est relu en base. C'est ce qui empêche
  qu'une URL bricolée aille lire un fichier ailleurs sur le disque.
  """
  use GarageWeb, :controller

  alias Garage.Atelier
  alias Garage.Stockage

  @doc "Affiche le PDF dans le navigateur."
  def show(conn, %{"id" => id}), do: envoyer(conn, id, "inline")

  @doc "Force le téléchargement."
  def download(conn, %{"id" => id}), do: envoyer(conn, id, "attachment")

  defp envoyer(conn, id, disposition) do
    document = Atelier.get_document!(id)
    chemin = Stockage.chemin_absolu(document.chemin)

    if File.exists?(chemin) do
      conn
      # nil : pas de charset, ce serait absurde sur un binaire.
      |> put_resp_content_type("application/pdf", nil)
      |> put_resp_header(
        "content-disposition",
        ~s(#{disposition}; filename="#{document.nom}")
      )
      # Le fichier est privé : il ne doit pas finir dans un cache partagé.
      |> put_resp_header("cache-control", "private, max-age=0, must-revalidate")
      |> send_file(200, chemin)
    else
      conn
      |> put_status(:not_found)
      |> put_view(html: GarageWeb.ErrorHTML)
      |> render(:"404")
    end
  end
end
