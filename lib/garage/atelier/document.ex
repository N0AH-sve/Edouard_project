defmodule Garage.Atelier.Document do
  @moduledoc """
  Un PDF archivé : carte grise, contrôle technique, devis, facture.

  Le fichier vit sur le disque, sous `UPLOADS_DIR` ; la base ne retient
  qu'un chemin **relatif**, pour que la sauvegarde reste restaurable si
  le dossier de données change de place.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @parents [:client_id, :vehicule_id, :intervention_id]

  schema "documents" do
    field :nom, :string
    field :chemin, :string
    field :content_type, :string
    field :taille, :integer

    belongs_to :client, Garage.Atelier.Client
    belongs_to :vehicule, Garage.Atelier.Vehicule
    belongs_to :intervention, Garage.Atelier.Intervention

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(document, attrs) do
    document
    |> cast(attrs, [:nom, :chemin, :content_type, :taille | @parents])
    |> validate_required([:nom, :chemin])
    |> validate_un_seul_parent()
    |> unique_constraint(:chemin)
    |> foreign_key_constraint(:client_id)
    |> foreign_key_constraint(:vehicule_id)
    |> foreign_key_constraint(:intervention_id)
  end

  # SQLite ne sait pas ajouter de CHECK après création de la table, cette
  # règle est donc tenue ici. Un document rattaché à rien serait invisible
  # dans l'interface ; rattaché à deux endroits, il apparaîtrait deux fois.
  defp validate_un_seul_parent(changeset) do
    renseignes =
      Enum.count(@parents, fn champ -> get_field(changeset, champ) != nil end)

    case renseignes do
      1 ->
        changeset

      0 ->
        add_error(
          changeset,
          :base,
          "le document doit être rattaché à un client, un véhicule ou une intervention"
        )

      _ ->
        add_error(changeset, :base, "le document ne peut être rattaché qu'à un seul élément")
    end
  end

  @doc "Taille lisible : « 1,2 Mo »."
  def taille_lisible(nil), do: "—"
  def taille_lisible(octets) when octets < 1024, do: "#{octets} o"

  def taille_lisible(octets) when octets < 1024 * 1024 do
    "#{:erlang.float_to_binary(octets / 1024, decimals: 0)} Ko"
  end

  def taille_lisible(octets) do
    "#{:erlang.float_to_binary(octets / (1024 * 1024), decimals: 1) |> String.replace(".", ",")} Mo"
  end
end
