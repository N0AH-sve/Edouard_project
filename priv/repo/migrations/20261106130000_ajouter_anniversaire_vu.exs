defmodule Garage.Repo.Migrations.AjouterAnniversaireVu do
  use Ecto.Migration

  def change do
    alter table(:reglages) do
      # Jour où la page d'anniversaire a été vue pour la dernière fois.
      # Sans cela, elle se rouvrirait à chaque navigation pendant 24 h.
      add :anniversaire_vu_le, :date
    end
  end
end
