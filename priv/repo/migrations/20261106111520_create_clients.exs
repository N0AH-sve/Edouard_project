defmodule Garage.Repo.Migrations.CreateClients do
  use Ecto.Migration

  def change do
    create table(:clients) do
      add :nom, :string, null: false
      add :prenom, :string
      add :telephone, :string
      add :email, :string
      add :adresse, :text
      add :code_postal, :string
      add :ville, :string
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    # Recherche par nom/prénom/téléphone depuis le tableau principal.
    # COLLATE NOCASE pour que « dupont » trouve « Dupont ».
    create index(:clients, ["nom COLLATE NOCASE"], name: :clients_nom_index)
    create index(:clients, ["prenom COLLATE NOCASE"], name: :clients_prenom_index)
    create index(:clients, [:telephone])
  end
end
