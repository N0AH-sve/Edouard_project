defmodule Garage.Repo.Migrations.CreateReglages do
  use Ecto.Migration

  def change do
    create table(:reglages) do
      add :nom, :string, null: false
      add :prenom, :string, null: false
      add :societe, :string, null: false
      add :email_pro, :string, null: false
      add :date_naissance, :date

      # Ces réglages sont un singleton : une seule ligne, saisie au
      # premier démarrage. La colonne vaut toujours 1 et l'index unique
      # empêche qu'une deuxième ligne apparaisse.
      #
      # SQLite ne sait pas ajouter de CHECK après coup (pas d'ALTER TABLE
      # ADD CONSTRAINT), d'où l'index unique plutôt qu'un CHECK = 1.
      add :singleton, :integer, null: false, default: 1

      timestamps(type: :utc_datetime)
    end

    create unique_index(:reglages, [:singleton])
  end
end
