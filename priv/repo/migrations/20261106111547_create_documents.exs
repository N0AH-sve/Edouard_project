defmodule Garage.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents) do
      add :nom, :string, null: false
      # Chemin RELATIF sous UPLOADS_DIR. Jamais absolu : la base doit
      # rester restaurable même si le dossier de données change de place.
      add :chemin, :string, null: false
      add :content_type, :string
      add :taille, :integer

      # Un document est rattaché à exactement UN des trois.
      # La règle est vérifiée dans le changeset : SQLite ne permet pas
      # d'ajouter un CHECK après la création de la table.
      add :client_id, references(:clients, on_delete: :delete_all)
      add :vehicule_id, references(:vehicules, on_delete: :delete_all)
      add :intervention_id, references(:interventions, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:documents, [:client_id])
    create index(:documents, [:vehicule_id])
    create index(:documents, [:intervention_id])
    create unique_index(:documents, [:chemin])
  end
end
