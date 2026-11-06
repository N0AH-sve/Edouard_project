defmodule Garage.Repo.Migrations.CreateVehicules do
  use Ecto.Migration

  def change do
    create table(:vehicules) do
      # L'immatriculation est la clé d'entrée du garagiste : un client
      # arrive, il tape la plaque. Normalisée en majuscules par le
      # changeset, donc un index unique simple suffit.
      add :immatriculation, :string, null: false
      add :marque, :string
      add :modele, :string
      add :annee, :integer
      add :vin, :string
      add :carburant, :string
      add :kilometrage, :integer
      add :date_prochain_ct, :date
      add :notes, :text

      # :restrict — supprimer un client qui a des véhicules échoue
      # bruyamment plutôt que d'effacer silencieusement son historique.
      add :client_id, references(:clients, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:vehicules, [:immatriculation])
    create index(:vehicules, [:client_id])
    create index(:vehicules, [:date_prochain_ct])
  end
end
