defmodule Garage.Stockage do
  @moduledoc """
  Rangement des PDF sur le disque.

  La base ne retient qu'un chemin **relatif** ; la racine vient de la
  configuration. Ainsi la sauvegarde reste restaurable même si le dossier
  de données change de place.

  Le nom du fichier sur le disque est **généré ici**, jamais repris de
  celui fourni par le navigateur : un nom comme `../../etc/passwd`
  écrirait ailleurs que prévu. Le nom d'origine n'est conservé que pour
  l'affichage, en base.
  """

  @entete_pdf "%PDF-"
  @taille_max 20 * 1024 * 1024

  @doc "Dossier racine des documents."
  @spec racine() :: String.t()
  def racine do
    Application.get_env(:garage, :uploads_dir) ||
      raise "la configuration :uploads_dir est absente"
  end

  @doc "Taille maximale acceptée, en octets."
  def taille_max, do: @taille_max

  @doc """
  Copie un fichier téléversé dans le dossier des documents.

  Renvoie les métadonnées à enregistrer en base.
  """
  @spec enregistrer(String.t(), String.t()) ::
          {:ok,
           %{nom: String.t(), chemin: String.t(), taille: integer(), content_type: String.t()}}
          | {:error, atom()}
  def enregistrer(source, nom_original) do
    with :ok <- verifier_pdf(source),
         {:ok, %File.Stat{size: taille}} <- File.stat(source),
         :ok <- verifier_taille(taille),
         chemin <- chemin_relatif(),
         destination <- Path.join(racine(), chemin),
         :ok <- File.mkdir_p(Path.dirname(destination)),
         :ok <- copier(source, destination) do
      {:ok,
       %{
         nom: nom_affichable(nom_original),
         chemin: chemin,
         taille: taille,
         content_type: "application/pdf"
       }}
    end
  end

  @doc "Chemin absolu d'un document, à partir de son chemin relatif."
  @spec chemin_absolu(String.t()) :: String.t()
  def chemin_absolu(relatif), do: Path.join(racine(), relatif)

  @doc "Supprime le fichier. L'absence du fichier n'est pas une erreur."
  @spec supprimer(String.t()) :: :ok
  def supprimer(relatif) do
    case relatif |> chemin_absolu() |> File.rm() do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, raison} -> {:error, raison}
    end
  end

  # Un fichier renommé en .pdf n'est pas un PDF. On vérifie l'en-tête
  # plutôt que de faire confiance à l'extension ou au type annoncé.
  defp verifier_pdf(source) do
    case File.open(source, [:read, :binary], &IO.binread(&1, 5)) do
      {:ok, @entete_pdf} -> :ok
      {:ok, _autre} -> {:error, :pas_un_pdf}
      {:error, _} -> {:error, :illisible}
    end
  end

  defp verifier_taille(taille) when taille > @taille_max, do: {:error, :trop_gros}
  defp verifier_taille(0), do: {:error, :fichier_vide}
  defp verifier_taille(_), do: :ok

  # Rangé par année : un dossier unique finirait par contenir des
  # milliers de fichiers, pénible à parcourir lors d'une restauration.
  defp chemin_relatif do
    Path.join(to_string(Date.utc_today().year), "#{Ecto.UUID.generate()}.pdf")
  end

  defp copier(source, destination) do
    case File.cp(source, destination) do
      :ok -> :ok
      {:error, raison} -> {:error, raison}
    end
  end

  # Le nom affiché est nettoyé : il finit dans un en-tête HTTP au
  # téléchargement, où un guillemet ou un retour à la ligne poserait
  # problème.
  defp nom_affichable(nom) do
    nom
    |> Path.basename()
    |> String.replace(~r/[\x00-\x1F"\\]/, "")
    |> String.trim()
    |> case do
      "" -> "document.pdf"
      propre -> String.slice(propre, 0, 150)
    end
  end
end
