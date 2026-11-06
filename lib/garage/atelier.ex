defmodule Garage.Atelier do
  @moduledoc """
  Le cœur métier : clients, véhicules, interventions, documents.

  Ces quatre notions forment une chaîne — un client possède des véhicules,
  un véhicule accumule des interventions, une intervention porte des
  documents — et vivent donc dans un seul contexte.
  """

  import Ecto.Query, warn: false

  alias Garage.Atelier.Client
  alias Garage.Atelier.Document
  alias Garage.Atelier.Intervention
  alias Garage.Atelier.Vehicule
  alias Garage.Repo

  # ---------------------------------------------------------------------------
  # Clients
  # ---------------------------------------------------------------------------

  @doc """
  Liste les clients, éventuellement filtrés par une recherche libre.

  La recherche porte sur le nom, le prénom, le téléphone, la ville — et
  sur l'immatriculation des véhicules, parce que c'est souvent la seule
  chose que le garagiste a sous les yeux.
  """
  def list_clients(opts \\ []) do
    recherche = opts |> Keyword.get(:recherche) |> normaliser_recherche()

    Client
    |> filtrer_clients(recherche)
    |> order_by([c], asc: c.nom, asc: c.prenom)
    |> Repo.all()
    |> Repo.preload(:vehicules)
  end

  defp filtrer_clients(query, nil), do: query

  defp filtrer_clients(query, terme) do
    {a, b} = motifs(terme)

    # Un client se retrouve aussi par la plaque d'un de ses véhicules :
    # c'est souvent la seule chose que le garagiste a sous les yeux.
    par_vehicule =
      from(v in Vehicule,
        where: like(v.recherche, ^a) or like(v.recherche, ^b),
        select: v.client_id
      )

    from(c in query,
      where:
        like(c.recherche, ^a) or like(c.recherche, ^b) or
          c.id in subquery(par_vehicule)
    )
  end

  def count_clients, do: Repo.aggregate(Client, :count)

  @doc "Charge un client avec ses véhicules et ses documents."
  def get_client!(id) do
    Client
    |> Repo.get!(id)
    |> Repo.preload([:documents, vehicules: from(v in Vehicule, order_by: v.immatriculation)])
  end

  def create_client(attrs) do
    %Client{} |> Client.changeset(attrs) |> Repo.insert()
  end

  def update_client(%Client{} = client, attrs) do
    client |> Client.changeset(attrs) |> Repo.update()
  end

  @doc """
  Supprime un client.

  Échoue si le client possède encore des véhicules : la base refuse
  (`:restrict`) plutôt que d'effacer silencieusement son historique.
  """
  def delete_client(%Client{} = client) do
    # SQLite ne nomme pas ses contraintes de clé étrangère dans l'erreur
    # renvoyée : `foreign_key_constraint/3` ne peut donc pas les attraper.
    # On vérifie en amont, et la contrainte en base reste le garde-fou.
    if Repo.exists?(from(v in Vehicule, where: v.client_id == ^client.id)) do
      {:error,
       client
       |> Ecto.Changeset.change()
       |> Ecto.Changeset.add_error(:id, "ce client a encore des véhicules enregistrés")}
    else
      Repo.delete(client)
    end
  end

  def change_client(%Client{} = client, attrs \\ %{}) do
    Client.changeset(client, attrs)
  end

  # ---------------------------------------------------------------------------
  # Véhicules
  # ---------------------------------------------------------------------------

  def list_vehicules(opts \\ []) do
    recherche = opts |> Keyword.get(:recherche) |> normaliser_recherche()

    Vehicule
    |> filtrer_vehicules(recherche)
    |> order_by([v], asc: v.immatriculation)
    |> Repo.all()
    |> Repo.preload(:client)
  end

  defp filtrer_vehicules(query, nil), do: query

  defp filtrer_vehicules(query, terme) do
    {a, b} = motifs(terme)

    from(v in query,
      left_join: c in assoc(v, :client),
      where:
        like(v.recherche, ^a) or like(v.recherche, ^b) or
          like(c.recherche, ^a) or like(c.recherche, ^b)
    )
  end

  def count_vehicules, do: Repo.aggregate(Vehicule, :count)

  @doc "Véhicules dont le contrôle technique arrive à échéance."
  def count_ct_a_prevoir(dans_jours \\ 60) do
    limite = Date.add(Date.utc_today(), dans_jours)

    Vehicule
    |> where([v], not is_nil(v.date_prochain_ct) and v.date_prochain_ct <= ^limite)
    |> Repo.aggregate(:count)
  end

  def get_vehicule!(id) do
    Vehicule
    |> Repo.get!(id)
    |> Repo.preload([
      :client,
      :documents,
      interventions: from(i in Intervention, order_by: [desc: i.date, desc: i.id])
    ])
  end

  def create_vehicule(attrs) do
    %Vehicule{} |> Vehicule.changeset(attrs) |> Repo.insert()
  end

  def update_vehicule(%Vehicule{} = vehicule, attrs) do
    vehicule |> Vehicule.changeset(attrs) |> Repo.update()
  end

  def delete_vehicule(%Vehicule{} = vehicule) do
    if Repo.exists?(from(i in Intervention, where: i.vehicule_id == ^vehicule.id)) do
      {:error,
       vehicule
       |> Ecto.Changeset.change()
       |> Ecto.Changeset.add_error(:id, "ce véhicule a un historique d'interventions")}
    else
      Repo.delete(vehicule)
    end
  end

  def change_vehicule(%Vehicule{} = vehicule, attrs \\ %{}) do
    Vehicule.changeset(vehicule, attrs)
  end

  @doc "Véhicules proposés dans les listes déroulantes."
  def options_vehicules do
    Vehicule
    |> order_by([v], asc: v.immatriculation)
    |> Repo.all()
    |> Repo.preload(:client)
    |> Enum.map(fn v ->
      client = if v.client, do: " — #{Client.nom_complet(v.client)}", else: ""
      {"#{v.immatriculation}#{client}", v.id}
    end)
  end

  def options_clients do
    Client
    |> order_by([c], asc: c.nom, asc: c.prenom)
    |> Repo.all()
    |> Enum.map(&{Client.nom_complet(&1), &1.id})
  end

  # ---------------------------------------------------------------------------
  # Interventions
  # ---------------------------------------------------------------------------

  def list_interventions(opts \\ []) do
    recherche = opts |> Keyword.get(:recherche) |> normaliser_recherche()
    statut = Keyword.get(opts, :statut)

    Intervention
    |> filtrer_interventions(recherche)
    |> filtrer_statut(statut)
    |> order_by([i], desc: i.date, desc: i.id)
    |> Repo.all()
    |> Repo.preload(vehicule: :client)
  end

  defp filtrer_interventions(query, nil), do: query

  defp filtrer_interventions(query, terme) do
    {a, b} = motifs(terme)

    from(i in query,
      left_join: v in assoc(i, :vehicule),
      left_join: c in assoc(v, :client),
      where:
        like(v.recherche, ^a) or like(v.recherche, ^b) or
          like(c.recherche, ^a) or like(c.recherche, ^b) or
          like(fragment("LOWER(?)", i.description), ^a) or
          like(fragment("LOWER(?)", i.pieces), ^a)
    )
  end

  defp filtrer_statut(query, nil), do: query
  defp filtrer_statut(query, statut), do: where(query, [i], i.statut == ^statut)

  def count_interventions, do: Repo.aggregate(Intervention, :count)

  def count_interventions_par_statut(statut) do
    Intervention |> where([i], i.statut == ^statut) |> Repo.aggregate(:count)
  end

  @doc "Chiffre d'affaires des interventions payées, en centimes."
  def total_encaisse do
    Intervention
    |> where([i], i.statut == :paye)
    |> Repo.aggregate(:sum, :montant_centimes)
    |> Kernel.||(0)
  end

  def get_intervention!(id) do
    Intervention
    |> Repo.get!(id)
    |> Repo.preload([:documents, vehicule: :client])
  end

  def create_intervention(attrs) do
    %Intervention{} |> Intervention.changeset(attrs) |> Repo.insert()
  end

  def update_intervention(%Intervention{} = intervention, attrs) do
    intervention |> Intervention.changeset(attrs) |> Repo.update()
  end

  def delete_intervention(%Intervention{} = intervention) do
    Repo.delete(intervention)
  end

  def change_intervention(%Intervention{} = intervention, attrs \\ %{}) do
    Intervention.changeset(intervention, attrs)
  end

  # ---------------------------------------------------------------------------
  # Documents
  # ---------------------------------------------------------------------------

  @doc """
  Range un PDF sur le disque puis enregistre sa fiche.

  `rattachement` vaut `{:client, id}`, `{:vehicule, id}` ou
  `{:intervention, id}`. Si l'enregistrement en base échoue, le fichier
  qui vient d'être écrit est retiré : mieux vaut aucun fichier qu'un
  fichier que plus rien ne référence.
  """
  @spec archiver_pdf(String.t(), String.t(), {atom(), integer()}) ::
          {:ok, Document.t()} | {:error, Ecto.Changeset.t() | atom()}
  def archiver_pdf(source, nom_original, {type, id} = _rattachement) do
    with {:ok, infos} <- Garage.Stockage.enregistrer(source, nom_original) do
      attrs =
        infos
        |> Map.new(fn {cle, valeur} -> {to_string(cle), valeur} end)
        |> Map.put(to_string(champ_rattachement(type)), id)

      case %Document{} |> Document.changeset(attrs) |> Repo.insert() do
        {:ok, document} ->
          {:ok, document}

        {:error, changeset} ->
          # Le fichier vient d'être écrit : on le retire pour ne pas
          # laisser d'orphelin sur le disque.
          Garage.Stockage.supprimer(infos.chemin)
          {:error, changeset}
      end
    end
  end

  defp champ_rattachement(:client), do: :client_id
  defp champ_rattachement(:vehicule), do: :vehicule_id
  defp champ_rattachement(:intervention), do: :intervention_id

  def get_document!(id), do: Repo.get!(Document, id)

  @doc "Documents rattachés à un élément, du plus récent au plus ancien."
  @spec list_documents({atom(), integer()}) :: [Document.t()]
  def list_documents({type, id}) do
    champ = champ_rattachement(type)

    Document
    |> where([d], field(d, ^champ) == ^id)
    |> order_by([d], desc: d.inserted_at, desc: d.id)
    |> Repo.all()
  end

  @doc """
  Supprime la fiche **et** le fichier sur le disque.

  L'ordre compte : la ligne part en premier, le fichier ensuite. Un
  fichier orphelin ne gêne personne ; une fiche qui pointe vers un
  fichier disparu casse l'affichage.
  """
  @spec supprimer_document(Document.t()) :: {:ok, Document.t()} | {:error, Ecto.Changeset.t()}
  def supprimer_document(%Document{} = document) do
    with {:ok, document} <- Repo.delete(document) do
      Garage.Stockage.supprimer(document.chemin)
      {:ok, document}
    end
  end

  # ---------------------------------------------------------------------------

  # Le terme tapé subit la même normalisation que les colonnes indexées,
  # sans quoi « Benoît » ne trouverait pas son propre enregistrement.
  #
  # Deux motifs, comme l'index en contient deux formes : « 06 12 34 56 78 »
  # doit trouver un numéro stocké « 0612345678 », et inversement.
  defp motifs(terme) do
    espace = Garage.Recherche.normaliser(terme)
    compact = String.replace(espace, " ", "")

    if espace == compact,
      do: {"%#{espace}%", "%#{espace}%"},
      else: {"%#{espace}%", "%#{compact}%"}
  end

  defp normaliser_recherche(nil), do: nil

  defp normaliser_recherche(terme) do
    case String.trim(terme) do
      "" -> nil
      t -> t
    end
  end
end
