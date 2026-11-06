defmodule Garage.ProfilFixtures do
  @moduledoc "Jeux d'essai pour le profil du garagiste."

  alias Garage.Profil

  def reglages_fixture(attrs \\ %{}) do
    {:ok, reglages} =
      attrs
      |> Enum.into(%{
        "nom" => "Durand",
        "prenom" => "Édouard",
        "societe" => "Garage Durand",
        "email_pro" => "contact@garage-durand.fr",
        "date_naissance" => "1985-04-12"
      })
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> Profil.enregistrer()

    reglages
  end
end
