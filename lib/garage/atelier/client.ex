defmodule Garage.Atelier.Client do
  @moduledoc "Un client du garage. Il peut posséder plusieurs véhicules."
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "clients" do
    field :nom, :string
    field :prenom, :string
    field :telephone, :string
    field :email, :string
    field :adresse, :string
    field :code_postal, :string
    field :ville, :string
    field :notes, :string
    field :recherche, :string, default: ""

    has_many :vehicules, Garage.Atelier.Vehicule
    has_many :documents, Garage.Atelier.Document

    timestamps(type: :utc_datetime)
  end

  @champs [:nom, :prenom, :telephone, :email, :adresse, :code_postal, :ville, :notes]

  @doc false
  def changeset(client, attrs) do
    client
    |> cast(attrs, @champs)
    |> update_change(:nom, &nettoyer/1)
    |> update_change(:prenom, &nettoyer/1)
    |> update_change(:ville, &nettoyer/1)
    |> update_change(:email, &nettoyer_email/1)
    |> update_change(:telephone, &nettoyer_telephone/1)
    |> validate_required([:nom], message: "le nom est obligatoire")
    |> validate_length(:nom, max: 100)
    |> validate_length(:prenom, max: 100)
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, message: "adresse e-mail invalide")
    |> validate_format(:code_postal, ~r/^\d{5}$/, message: "doit comporter 5 chiffres")
    |> indexer()
  end

  # Recalculée à chaque écriture : c'est elle que la recherche interroge.
  defp indexer(changeset) do
    valeurs =
      Enum.map(
        [:nom, :prenom, :telephone, :email, :ville, :code_postal],
        &get_field(changeset, &1)
      )

    put_change(changeset, :recherche, Garage.Recherche.index(valeurs))
  end

  @doc "Nom affichable : « Dupont Jean » ou « Dupont » si le prénom manque."
  def nom_complet(%__MODULE__{nom: nom, prenom: nil}), do: nom
  def nom_complet(%__MODULE__{nom: nom, prenom: ""}), do: nom
  def nom_complet(%__MODULE__{nom: nom, prenom: prenom}), do: "#{nom} #{prenom}"

  defp nettoyer(nil), do: nil
  defp nettoyer(v), do: String.trim(v)

  defp nettoyer_email(nil), do: nil
  defp nettoyer_email(v), do: v |> String.trim() |> String.downcase()

  # On retire les séparateurs de saisie pour que la recherche par
  # téléphone fonctionne quelle que soit la façon de taper le numéro.
  defp nettoyer_telephone(nil), do: nil

  defp nettoyer_telephone(v) do
    v |> String.replace(~r/[\s.\-()]/, "") |> String.trim()
  end
end
