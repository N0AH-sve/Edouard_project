defmodule Garage.AtelierFixtures do
  @moduledoc """
  Jeux d'essai pour les tests de l'atelier.

  Les fixtures respectent les contraintes de la base : un véhicule a
  toujours un propriétaire, une intervention toujours un véhicule.
  """

  alias Garage.Atelier

  def client_fixture(attrs \\ %{}) do
    {:ok, client} =
      attrs
      |> Enum.into(%{
        nom: "Dupont",
        prenom: "Jean",
        telephone: "0612345678",
        email: "jean.dupont@example.fr",
        ville: "Annecy",
        code_postal: "74000"
      })
      |> Atelier.create_client()

    client
  end

  @doc """
  Crée un véhicule. Un client est créé au besoin : la base refuse un
  véhicule orphelin.
  """
  def vehicule_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})

    client_id = Map.get_lazy(attrs, :client_id, fn -> client_fixture().id end)

    {:ok, vehicule} =
      attrs
      |> Enum.into(%{
        immatriculation: plaque_unique(),
        marque: "Renault",
        modele: "Clio",
        annee: 2018,
        carburant: :essence,
        kilometrage: 85_000,
        client_id: client_id
      })
      |> Atelier.create_vehicule()

    vehicule
  end

  def intervention_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})

    vehicule_id = Map.get_lazy(attrs, :vehicule_id, fn -> vehicule_fixture().id end)

    {:ok, intervention} =
      attrs
      |> Enum.into(%{
        date: Date.utc_today(),
        type: :revision,
        statut: :devis,
        kilometrage: 90_000,
        description: "Révision complète",
        montant_euros: "249,90",
        vehicule_id: vehicule_id
      })
      |> Atelier.create_intervention()

    intervention
  end

  @doc "Plaque au format français, unique à chaque appel."
  def plaque_unique do
    n = System.unique_integer([:positive]) |> rem(1000)
    lettres = fn -> Enum.map_join(1..2, "", fn _ -> <<Enum.random(?A..?Z)>> end) end

    "#{lettres.()}-#{String.pad_leading(Integer.to_string(n), 3, "0")}-#{lettres.()}"
  end
end
