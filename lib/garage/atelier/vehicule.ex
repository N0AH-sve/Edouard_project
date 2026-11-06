defmodule Garage.Atelier.Vehicule do
  @moduledoc """
  Un véhicule confié au garage.

  L'immatriculation est la clé d'entrée du métier : le client arrive, le
  garagiste tape la plaque. Elle est donc normalisée et unique.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @carburants [
    essence: "Essence",
    diesel: "Diesel",
    hybride: "Hybride",
    electrique: "Électrique",
    gpl: "GPL",
    autre: "Autre"
  ]

  schema "vehicules" do
    field :immatriculation, :string
    field :marque, :string
    field :modele, :string
    field :annee, :integer
    field :vin, :string
    field :carburant, Ecto.Enum, values: Keyword.keys(@carburants)
    field :kilometrage, :integer
    field :date_prochain_ct, :date
    field :notes, :string
    field :recherche, :string, default: ""

    belongs_to :client, Garage.Atelier.Client
    has_many :interventions, Garage.Atelier.Intervention
    has_many :documents, Garage.Atelier.Document

    timestamps(type: :utc_datetime)
  end

  @champs [
    :immatriculation,
    :marque,
    :modele,
    :annee,
    :vin,
    :carburant,
    :kilometrage,
    :date_prochain_ct,
    :notes,
    :client_id
  ]

  @doc "Libellés des carburants, pour les listes déroulantes."
  def carburants, do: Enum.map(@carburants, fn {cle, libelle} -> {libelle, cle} end)

  def libelle_carburant(nil), do: "—"
  def libelle_carburant(cle), do: Keyword.get(@carburants, cle, "—")

  @doc false
  def changeset(vehicule, attrs) do
    vehicule
    |> cast(attrs, @champs)
    |> update_change(:immatriculation, &normaliser_plaque/1)
    |> update_change(:marque, &nettoyer/1)
    |> update_change(:modele, &nettoyer/1)
    |> update_change(:vin, &normaliser_vin/1)
    |> validate_required([:immatriculation, :client_id],
      message: "ce champ est obligatoire"
    )
    |> validate_length(:immatriculation, min: 4, max: 15)
    |> validate_number(:annee,
      greater_than_or_equal_to: 1900,
      less_than_or_equal_to: Date.utc_today().year + 1,
      message: "année invalide"
    )
    |> validate_number(:kilometrage,
      greater_than_or_equal_to: 0,
      message: "le kilométrage ne peut pas être négatif"
    )
    |> validate_length(:vin, is: 17, message: "un VIN comporte 17 caractères")
    |> unique_constraint(:immatriculation,
      message: "un véhicule porte déjà cette immatriculation"
    )
    |> foreign_key_constraint(:client_id)
    |> indexer()
  end

  defp indexer(changeset) do
    valeurs =
      Enum.map([:immatriculation, :marque, :modele, :vin], &get_field(changeset, &1)) ++
        [to_string(get_field(changeset, :annee) || "")]

    put_change(changeset, :recherche, Garage.Recherche.index(valeurs))
  end

  @doc """
  Met la plaque sous une forme unique : majuscules, tirets simples.

  Sans cela « ab-123-cd » et « AB 123 CD » créeraient deux véhicules
  distincts et l'index unique ne servirait à rien.
  """
  def normaliser_plaque(nil), do: nil

  def normaliser_plaque(valeur) do
    valeur
    |> String.upcase()
    |> String.replace(~r/[^A-Z0-9]/u, "")
    |> formater_plaque()
  end

  # Format français courant AA-123-AA. Les autres formats sont conservés
  # tels quels, sans séparateur : on ne devine pas les plaques étrangères.
  defp formater_plaque(<<a::binary-2, n::binary-3, b::binary-2>> = plaque) do
    if String.match?(a, ~r/^[A-Z]{2}$/) and String.match?(n, ~r/^\d{3}$/) and
         String.match?(b, ~r/^[A-Z]{2}$/),
       do: "#{a}-#{n}-#{b}",
       else: plaque
  end

  defp formater_plaque(plaque), do: plaque

  defp normaliser_vin(nil), do: nil
  defp normaliser_vin(v), do: v |> String.trim() |> String.upcase()

  defp nettoyer(nil), do: nil
  defp nettoyer(v), do: String.trim(v)
end
