defmodule Garage.Repo.Migrations.CreateInterventions do
  use Ecto.Migration

  def change do
    create table(:interventions) do
      add :date, :date, null: false
      add :type, :string, null: false, default: "reparation"
      add :kilometrage, :integer
      add :description, :text
      add :pieces, :text

      # Montant en centimes entiers : SQLite n'a pas de décimal natif et
      # les flottants faussent les totaux de facture.
      add :montant_centimes, :integer, null: false, default: 0

      add :statut, :string, null: false, default: "devis"
      add :vehicule_id, references(:vehicules, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    # L'historique d'un véhicule se lit du plus récent au plus ancien.
    create index(:interventions, [:vehicule_id, :date])
    create index(:interventions, [:statut])
  end
end
