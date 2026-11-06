defmodule Garage.AtelierTest do
  use Garage.DataCase, async: true

  import Garage.AtelierFixtures

  alias Garage.Atelier
  alias Garage.Atelier.Client
  alias Garage.Atelier.Intervention
  alias Garage.Atelier.Vehicule

  describe "clients" do
    test "create_client/1 exige un nom" do
      assert {:error, changeset} = Atelier.create_client(%{nom: ""})
      assert %{nom: ["le nom est obligatoire"]} = errors_on(changeset)
    end

    test "create_client/1 nettoie le téléphone et l'e-mail" do
      client = client_fixture(telephone: "06 12 34 56 78", email: "  JEAN@Example.FR ")

      assert client.telephone == "0612345678"
      assert client.email == "jean@example.fr"
    end

    test "create_client/1 refuse un code postal mal formé" do
      assert {:error, changeset} = Atelier.create_client(%{nom: "X", code_postal: "7400"})
      assert %{code_postal: ["doit comporter 5 chiffres"]} = errors_on(changeset)
    end

    test "delete_client/1 refuse de supprimer un client qui a un véhicule" do
      vehicule = vehicule_fixture()
      client = Atelier.get_client!(vehicule.client_id)

      assert {:error, changeset} = Atelier.delete_client(client)
      assert %{id: ["ce client a encore des véhicules enregistrés"]} = errors_on(changeset)

      # Le client est toujours là : aucun historique n'a été perdu.
      assert Atelier.get_client!(client.id)
    end

    test "delete_client/1 accepte un client sans véhicule" do
      client = client_fixture()
      assert {:ok, _} = Atelier.delete_client(client)
      assert_raise Ecto.NoResultsError, fn -> Atelier.get_client!(client.id) end
    end

    test "nom_complet/1 tolère l'absence de prénom" do
      assert Client.nom_complet(%Client{nom: "Dupont", prenom: nil}) == "Dupont"
      assert Client.nom_complet(%Client{nom: "Dupont", prenom: "Jean"}) == "Dupont Jean"
    end
  end

  describe "recherche de clients" do
    setup do
      benoit = client_fixture(nom: "Benoît", prenom: "Céline", ville: "Thônes", email: nil)
      martin = client_fixture(nom: "Martin", prenom: "Paul", telephone: "0699887766")
      vehicule = vehicule_fixture(immatriculation: "ZZ-999-ZZ", client_id: martin.id)

      %{benoit: benoit, martin: martin, vehicule: vehicule}
    end

    test "sans terme, renvoie tout le monde" do
      assert length(Atelier.list_clients()) == 2
    end

    test "ignore les accents", %{benoit: benoit} do
      assert [trouve] = Atelier.list_clients(recherche: "benoit")
      assert trouve.id == benoit.id

      assert [^trouve] = Atelier.list_clients(recherche: "BENOIT")
    end

    test "ignore les accents dans la ville", %{benoit: benoit} do
      assert [trouve] = Atelier.list_clients(recherche: "thones")
      assert trouve.id == benoit.id
    end

    test "trouve par téléphone, espacé ou non", %{martin: martin} do
      assert [a] = Atelier.list_clients(recherche: "0699887766")
      assert [b] = Atelier.list_clients(recherche: "06 99 88 77 66")
      assert a.id == martin.id and b.id == martin.id
    end

    test "trouve un client par la plaque de son véhicule", %{martin: martin} do
      assert [trouve] = Atelier.list_clients(recherche: "ZZ-999-ZZ")
      assert trouve.id == martin.id

      # Et sans les tirets, comme on tape naturellement une plaque.
      assert [^trouve] = Atelier.list_clients(recherche: "zz999zz")
    end

    test "ne renvoie rien pour un terme absent" do
      assert Atelier.list_clients(recherche: "zzzinconnu") == []
    end
  end

  describe "véhicules" do
    test "l'immatriculation est normalisée" do
      for saisie <- ["ab-123-cd", "AB 123 CD", "ab123cd", " ab.123.cd "] do
        vehicule = vehicule_fixture(immatriculation: saisie)
        assert vehicule.immatriculation == "AB-123-CD"
        Garage.Repo.delete!(vehicule)
      end
    end

    test "deux véhicules ne peuvent pas partager une plaque" do
      vehicule_fixture(immatriculation: "AB-123-CD")

      assert {:error, changeset} =
               Atelier.create_vehicule(%{
                 immatriculation: "ab 123 cd",
                 client_id: client_fixture().id
               })

      assert %{immatriculation: ["un véhicule porte déjà cette immatriculation"]} =
               errors_on(changeset)
    end

    test "un véhicule doit avoir un propriétaire" do
      assert {:error, changeset} = Atelier.create_vehicule(%{immatriculation: "AB-123-CD"})
      assert %{client_id: ["ce champ est obligatoire"]} = errors_on(changeset)
    end

    test "refuse une année incohérente" do
      assert {:error, changeset} =
               Atelier.create_vehicule(%{
                 immatriculation: "AB-123-CD",
                 client_id: client_fixture().id,
                 annee: 1850
               })

      assert %{annee: ["année invalide"]} = errors_on(changeset)
    end

    test "refuse un kilométrage négatif" do
      assert {:error, changeset} =
               Atelier.create_vehicule(%{
                 immatriculation: "AB-123-CD",
                 client_id: client_fixture().id,
                 kilometrage: -5
               })

      assert %{kilometrage: ["le kilométrage ne peut pas être négatif"]} = errors_on(changeset)
    end

    test "delete_vehicule/1 refuse si un historique existe" do
      intervention = intervention_fixture()
      vehicule = Atelier.get_vehicule!(intervention.vehicule_id)

      assert {:error, changeset} = Atelier.delete_vehicule(vehicule)
      assert %{id: ["ce véhicule a un historique d'interventions"]} = errors_on(changeset)
    end

    test "recherche par marque et par plaque sans tirets" do
      vehicule_fixture(immatriculation: "QS-456-TU", marque: "Citroën")

      assert [_] = Atelier.list_vehicules(recherche: "citroen")
      assert [_] = Atelier.list_vehicules(recherche: "qs456tu")
    end
  end

  describe "interventions" do
    test "le montant saisi en euros est stocké en centimes" do
      intervention = intervention_fixture(montant_euros: "1 234,56")
      assert intervention.montant_centimes == 123_456
    end

    test "un montant illisible est refusé" do
      assert {:error, changeset} =
               Atelier.create_intervention(%{
                 date: Date.utc_today(),
                 type: :revision,
                 statut: :devis,
                 vehicule_id: vehicule_fixture().id,
                 montant_euros: "beaucoup"
               })

      assert %{montant_euros: ["montant invalide"]} = errors_on(changeset)
    end

    test "une intervention ne peut pas être datée dans le futur" do
      assert {:error, changeset} =
               Atelier.create_intervention(%{
                 date: Date.add(Date.utc_today(), 1),
                 type: :revision,
                 statut: :devis,
                 vehicule_id: vehicule_fixture().id
               })

      assert %{date: ["une intervention ne peut pas être datée dans le futur"]} =
               errors_on(changeset)
    end

    test "une intervention doit porter sur un véhicule" do
      assert {:error, changeset} =
               Atelier.create_intervention(%{date: Date.utc_today(), type: :revision})

      assert %{vehicule_id: ["ce champ est obligatoire"]} = errors_on(changeset)
    end

    test "total_encaisse/0 ne compte que les interventions payées" do
      vehicule = vehicule_fixture()
      intervention_fixture(vehicule_id: vehicule.id, montant_euros: "100", statut: :paye)
      intervention_fixture(vehicule_id: vehicule.id, montant_euros: "200", statut: :paye)
      intervention_fixture(vehicule_id: vehicule.id, montant_euros: "999", statut: :devis)

      assert Atelier.total_encaisse() == 30_000
    end

    test "l'historique d'un véhicule est trié du plus récent au plus ancien" do
      vehicule = vehicule_fixture()
      aujourdhui = Date.utc_today()

      intervention_fixture(vehicule_id: vehicule.id, date: Date.add(aujourdhui, -30))
      intervention_fixture(vehicule_id: vehicule.id, date: aujourdhui)
      intervention_fixture(vehicule_id: vehicule.id, date: Date.add(aujourdhui, -10))

      dates = Atelier.get_vehicule!(vehicule.id).interventions |> Enum.map(& &1.date)
      assert dates == Enum.sort(dates, {:desc, Date})
    end

    test "filtre par statut" do
      vehicule = vehicule_fixture()
      intervention_fixture(vehicule_id: vehicule.id, statut: :en_cours)
      intervention_fixture(vehicule_id: vehicule.id, statut: :paye)

      assert [i] = Atelier.list_interventions(statut: :en_cours)
      assert i.statut == :en_cours
      assert Atelier.count_interventions_par_statut(:paye) == 1
    end
  end

  describe "conversion des montants" do
    test "parser_euros/1 accepte virgule, point et espaces" do
      assert Intervention.parser_euros("149,90") == {:ok, 14_990}
      assert Intervention.parser_euros("149.90") == {:ok, 14_990}
      assert Intervention.parser_euros("1 234,56") == {:ok, 123_456}
      assert Intervention.parser_euros("0") == {:ok, 0}
      assert Intervention.parser_euros("abc") == :error
    end

    test "formater_euros/1 produit un montant lisible" do
      assert Intervention.formater_euros(0) == "0,00 €"
      assert Intervention.formater_euros(990) == "9,90 €"
      assert Intervention.formater_euros(267_456) == "2 674,56 €"
    end

    test "un aller-retour euros → centimes → euros est stable" do
      for saisie <- ["0,00", "9,90", "149,90", "2 674,56"] do
        assert {:ok, centimes} = Intervention.parser_euros(saisie)
        attendu = saisie |> String.replace(" ", " ") |> Kernel.<>(" €")
        assert Intervention.formater_euros(centimes) == attendu
      end
    end
  end

  describe "normalisation des plaques" do
    test "ramène les formats courants à AA-123-AA" do
      assert Vehicule.normaliser_plaque("ab-123-cd") == "AB-123-CD"
      assert Vehicule.normaliser_plaque("AB 123 CD") == "AB-123-CD"
      assert Vehicule.normaliser_plaque("ab123cd") == "AB-123-CD"
    end

    test "laisse les formats inconnus sans séparateur" do
      assert Vehicule.normaliser_plaque("1234 ABC") == "1234ABC"
    end
  end
end
