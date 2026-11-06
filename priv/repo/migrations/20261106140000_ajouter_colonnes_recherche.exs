defmodule Garage.Repo.Migrations.AjouterColonnesRecherche do
  use Ecto.Migration

  @moduledoc """
  Colonnes de recherche aplaties (sans accent, minuscules).

  SQLite ne compare que l'ASCII : sans cela, « benoit » ne trouverait
  jamais « Benoît ».
  """

  def change do
    alter table(:clients) do
      add :recherche, :text, null: false, default: ""
    end

    alter table(:vehicules) do
      add :recherche, :text, null: false, default: ""
    end

    create index(:clients, [:recherche])
    create index(:vehicules, [:recherche])
  end
end
