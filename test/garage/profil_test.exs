defmodule Garage.ProfilTest do
  use Garage.DataCase, async: true

  import Garage.ProfilFixtures

  alias Garage.Profil
  alias Garage.Profil.Reglages

  describe "enregistrement" do
    test "le premier enregistrement crée le profil" do
      refute Profil.configure?()
      reglages = reglages_fixture()

      assert Profil.configure?()
      assert reglages.nom == "Durand"
      assert reglages.date_naissance == ~D[1985-04-12]
    end

    test "l'e-mail est nettoyé" do
      reglages = reglages_fixture(%{"email_pro" => "  CONTACT@Garage.FR  "})
      assert reglages.email_pro == "contact@garage.fr"
    end

    test "tous les champs sont obligatoires" do
      assert {:error, changeset} = Profil.enregistrer(%{})
      erreurs = errors_on(changeset)

      for champ <- [:nom, :prenom, :societe, :email_pro, :date_naissance] do
        assert erreurs[champ] == ["ce champ est obligatoire"]
      end
    end

    test "refuse un e-mail invalide" do
      assert {:error, changeset} = Profil.enregistrer(%{"email_pro" => "pas-un-email"})
      assert "adresse e-mail invalide" in errors_on(changeset).email_pro
    end

    test "refuse une date de naissance dans le futur" do
      demain = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()
      assert {:error, changeset} = Profil.enregistrer(%{"date_naissance" => demain})
      assert "la date ne peut pas être dans le futur" in errors_on(changeset).date_naissance
    end

    test "un second profil est impossible" do
      reglages_fixture()

      assert {:error, changeset} =
               %Reglages{}
               |> Reglages.changeset(%{
                 "nom" => "Autre",
                 "prenom" => "Quelqu'un",
                 "societe" => "Autre garage",
                 "email_pro" => "autre@example.fr",
                 "date_naissance" => "1990-01-01"
               })
               |> Garage.Repo.insert()

      assert "un profil existe déjà" in errors_on(changeset).singleton
    end
  end

  describe "la date de naissance n'est pas modifiable" do
    setup do: %{reglages: reglages_fixture()}

    test "une tentative de modification est ignorée", %{reglages: reglages} do
      {:ok, maj} =
        Profil.enregistrer(%{
          "nom" => "Durand",
          "prenom" => "Édouard",
          "societe" => "Garage Durand",
          "email_pro" => "contact@garage-durand.fr",
          "date_naissance" => "2000-01-01"
        })

      assert maj.date_naissance == reglages.date_naissance
      refute maj.date_naissance == ~D[2000-01-01]
    end

    test "les autres champs restent modifiables" do
      {:ok, maj} =
        Profil.enregistrer(%{
          "nom" => "Durand-Martin",
          "prenom" => "Édouard",
          "societe" => "Garage du Lac",
          "email_pro" => "contact@garagedulac.fr"
        })

      assert maj.nom == "Durand-Martin"
      assert maj.societe == "Garage du Lac"
    end
  end

  describe "anniversaire" do
    test "vrai le jour même, faux les autres jours" do
      reglages = %Reglages{date_naissance: ~D[1985-04-12]}

      assert Profil.anniversaire_aujourdhui?(reglages, ~D[2026-04-12])
      assert Profil.anniversaire_aujourdhui?(reglages, ~D[2031-04-12])
      refute Profil.anniversaire_aujourdhui?(reglages, ~D[2026-04-11])
      refute Profil.anniversaire_aujourdhui?(reglages, ~D[2026-05-12])
    end

    test "sans profil, il n'y a pas d'anniversaire" do
      refute Profil.anniversaire_aujourdhui?(nil, ~D[2026-04-12])
    end

    test "un 29 février est fêté le 28 les années non bissextiles" do
      reglages = %Reglages{date_naissance: ~D[2000-02-29]}

      # 2028 est bissextile : le vrai jour existe.
      assert Profil.anniversaire_aujourdhui?(reglages, ~D[2028-02-29])
      refute Profil.anniversaire_aujourdhui?(reglages, ~D[2028-02-28])

      # 2027 ne l'est pas : on fête la veille plutôt que de sauter l'année.
      assert Profil.anniversaire_aujourdhui?(reglages, ~D[2027-02-28])
      refute Profil.anniversaire_aujourdhui?(reglages, ~D[2027-03-01])
    end

    test "souhaiter?/2 ne se déclenche qu'une fois par jour" do
      pas_vu = %Reglages{date_naissance: ~D[1985-04-12], anniversaire_vu_le: nil}
      vu = %Reglages{date_naissance: ~D[1985-04-12], anniversaire_vu_le: ~D[2026-04-12]}
      vu_hier = %Reglages{date_naissance: ~D[1985-04-12], anniversaire_vu_le: ~D[2025-04-12]}

      assert Profil.souhaiter?(pas_vu, ~D[2026-04-12])
      refute Profil.souhaiter?(vu, ~D[2026-04-12])
      assert Profil.souhaiter?(vu_hier, ~D[2026-04-12])
      refute Profil.souhaiter?(pas_vu, ~D[2026-04-13])
    end

    test "marquer_souhaite/2 empêche le réaffichage" do
      reglages = reglages_fixture(%{"date_naissance" => "1985-04-12"})
      assert Profil.souhaiter?(reglages, ~D[2026-04-12])

      {:ok, marque} = Profil.marquer_souhaite(reglages, ~D[2026-04-12])
      refute Profil.souhaiter?(marque, ~D[2026-04-12])

      # L'année suivante, la page revient.
      assert Profil.souhaiter?(marque, ~D[2027-04-12])
    end

    test "age/2 tient compte du jour dans l'année" do
      reglages = %Reglages{date_naissance: ~D[1985-04-12]}

      assert Profil.age(reglages, ~D[2026-04-12]) == 41
      assert Profil.age(reglages, ~D[2026-04-11]) == 40
      assert Profil.age(reglages, ~D[2026-12-31]) == 41
    end
  end
end
