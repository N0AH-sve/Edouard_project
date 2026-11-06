defmodule Garage.Profil do
  @moduledoc """
  Accès au profil du garagiste (singleton).

  L'application n'a pas de comptes ni d'authentification : elle n'écoute
  que sur 127.0.0.1, donc seule la personne devant le Mac peut l'ouvrir.
  Ce profil n'est pas une identité de connexion, c'est l'en-tête qui
  figurera sur les documents.
  """

  alias Garage.Profil.Reglages
  alias Garage.Repo

  @doc """
  Renvoie le profil, ou `nil` si le premier démarrage n'a pas encore eu lieu.
  """
  @spec get_reglages() :: Reglages.t() | nil
  def get_reglages, do: Repo.one(Reglages)

  @doc """
  Vrai lorsque le profil a été saisi. Utilisé par le plug d'accueil pour
  décider s'il faut afficher l'écran de bienvenue.
  """
  @spec configure?() :: boolean()
  def configure?, do: Repo.aggregate(Reglages, :count) > 0

  @doc """
  Crée le profil au premier démarrage, ou met à jour celui qui existe.

  Une seule ligne peut exister : l'index unique sur `singleton` le garantit
  côté base, même si deux onglets soumettaient le formulaire en même temps.
  """
  @spec enregistrer(map()) :: {:ok, Reglages.t()} | {:error, Ecto.Changeset.t()}
  def enregistrer(attrs) do
    (get_reglages() || %Reglages{})
    |> Reglages.changeset(attrs)
    |> Repo.insert_or_update()
  end

  @doc """
  Changeset pour les formulaires (bienvenue et réglages).
  """
  @spec change_reglages(Reglages.t() | nil, map()) :: Ecto.Changeset.t()
  def change_reglages(reglages \\ nil, attrs \\ %{}) do
    Reglages.changeset(reglages || %Reglages{}, attrs)
  end

  @doc """
  Vrai si aujourd'hui est l'anniversaire du garagiste.

  Un 29 février est fêté le 28 les années non bissextiles : sinon
  l'anniversaire disparaîtrait trois années sur quatre.
  """
  @spec anniversaire_aujourdhui?(Reglages.t() | nil, Date.t()) :: boolean()
  def anniversaire_aujourdhui?(reglages, aujourdhui \\ Date.utc_today())

  def anniversaire_aujourdhui?(nil, _aujourdhui), do: false
  def anniversaire_aujourdhui?(%Reglages{date_naissance: nil}, _aujourdhui), do: false

  def anniversaire_aujourdhui?(%Reglages{date_naissance: naissance}, aujourdhui) do
    {mois, jour} = jour_de_fete(naissance, aujourdhui.year)
    aujourdhui.month == mois and aujourdhui.day == jour
  end

  defp jour_de_fete(%Date{month: 2, day: 29}, annee) do
    if Date.leap_year?(%Date{year: annee, month: 1, day: 1}),
      do: {2, 29},
      else: {2, 28}
  end

  defp jour_de_fete(%Date{month: mois, day: jour}, _annee), do: {mois, jour}

  @doc """
  Vrai s'il faut afficher la page d'anniversaire : c'est le jour, et elle
  n'a pas encore été vue aujourd'hui.
  """
  @spec souhaiter?(Reglages.t() | nil, Date.t()) :: boolean()
  def souhaiter?(reglages, aujourdhui \\ Date.utc_today())

  def souhaiter?(nil, _aujourdhui), do: false

  def souhaiter?(%Reglages{} = reglages, aujourdhui) do
    anniversaire_aujourdhui?(reglages, aujourdhui) and
      reglages.anniversaire_vu_le != aujourdhui
  end

  @doc """
  Mémorise que la page d'anniversaire a été vue, pour ne pas la réafficher
  à chaque navigation de la journée.
  """
  @spec marquer_souhaite(Reglages.t(), Date.t()) ::
          {:ok, Reglages.t()} | {:error, Ecto.Changeset.t()}
  def marquer_souhaite(%Reglages{} = reglages, aujourdhui \\ Date.utc_today()) do
    reglages
    |> Ecto.Changeset.change(anniversaire_vu_le: aujourdhui)
    |> Repo.update()
  end

  @doc """
  Âge atteint aujourd'hui.
  """
  @spec age(Reglages.t(), Date.t()) :: integer()
  def age(%Reglages{date_naissance: naissance}, aujourdhui \\ Date.utc_today()) do
    annees = aujourdhui.year - naissance.year

    if {aujourdhui.month, aujourdhui.day} < {naissance.month, naissance.day},
      do: annees - 1,
      else: annees
  end

  @doc """
  Nom affichable du garagiste, pour l'en-tête de l'application.
  """
  @spec nom_complet(Reglages.t() | nil) :: String.t()
  def nom_complet(nil), do: ""
  def nom_complet(%Reglages{prenom: p, nom: n}), do: String.trim("#{p} #{n}")
end
