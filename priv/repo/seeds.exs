# Jeu d'essai pour le développement.
#
#     mix run priv/repo/seeds.exs
#
# Idempotent : on repart d'une base vide à chaque fois.

alias Garage.Atelier
alias Garage.Repo

Repo.delete_all(Garage.Atelier.Document)
Repo.delete_all(Garage.Atelier.Intervention)
Repo.delete_all(Garage.Atelier.Vehicule)
Repo.delete_all(Garage.Atelier.Client)

clients = [
  %{
    nom: "Bernard",
    prenom: "Martine",
    telephone: "06 12 34 56 78",
    email: "m.bernard@example.fr",
    ville: "Annecy",
    code_postal: "74000"
  },
  %{
    nom: "Dubois",
    prenom: "Karim",
    telephone: "07 98 76 54 32",
    email: "karim.dubois@example.fr",
    ville: "Chambéry",
    code_postal: "73000"
  },
  %{
    nom: "Lefèvre",
    prenom: "Sophie",
    telephone: "06 44 22 11 09",
    email: "s.lefevre@example.fr",
    ville: "Annecy",
    code_postal: "74000"
  },
  %{
    nom: "Moreau",
    prenom: "Jean-Pierre",
    telephone: "04 50 12 00 44",
    ville: "Rumilly",
    code_postal: "74150"
  },
  %{
    nom: "Nguyen",
    prenom: "Linh",
    telephone: "06 77 88 99 00",
    email: "linh.nguyen@example.fr",
    ville: "Aix-les-Bains",
    code_postal: "73100"
  },
  %{
    nom: "Garcia",
    prenom: "Pablo",
    telephone: "06 31 42 53 64",
    ville: "Annecy",
    code_postal: "74940"
  }
]

inseres =
  Enum.map(clients, fn attrs ->
    {:ok, c} = Atelier.create_client(attrs)
    c
  end)

[bernard, dubois, lefevre, moreau, nguyen, garcia] = inseres

vehicules = [
  {bernard,
   %{
     immatriculation: "AB-123-CD",
     marque: "Renault",
     modele: "Clio IV",
     annee: 2016,
     carburant: :essence,
     kilometrage: 128_400,
     date_prochain_ct: ~D[2026-03-14]
   }},
  {bernard,
   %{
     immatriculation: "EF-456-GH",
     marque: "Dacia",
     modele: "Duster",
     annee: 2020,
     carburant: :diesel,
     kilometrage: 61_200,
     date_prochain_ct: ~D[2027-09-02]
   }},
  {dubois,
   %{
     immatriculation: "IJ-789-KL",
     marque: "Peugeot",
     modele: "308",
     annee: 2018,
     carburant: :diesel,
     kilometrage: 94_750,
     date_prochain_ct: ~D[2026-01-20]
   }},
  {lefevre,
   %{
     immatriculation: "MN-012-OP",
     marque: "Toyota",
     modele: "Yaris Hybride",
     annee: 2021,
     carburant: :hybride,
     kilometrage: 42_300,
     date_prochain_ct: ~D[2027-05-11]
   }},
  {moreau,
   %{
     immatriculation: "QR-345-ST",
     marque: "Citroën",
     modele: "Berlingo",
     annee: 2014,
     carburant: :diesel,
     kilometrage: 213_900,
     date_prochain_ct: ~D[2025-12-30]
   }},
  {nguyen,
   %{
     immatriculation: "UV-678-WX",
     marque: "Tesla",
     modele: "Model 3",
     annee: 2022,
     carburant: :electrique,
     kilometrage: 38_100,
     date_prochain_ct: ~D[2028-04-18]
   }},
  {garcia,
   %{
     immatriculation: "YZ-901-AB",
     marque: "Volkswagen",
     modele: "Golf VII",
     annee: 2017,
     carburant: :essence,
     kilometrage: 105_600,
     date_prochain_ct: ~D[2026-02-08]
   }}
]

vehicules_inseres =
  Enum.map(vehicules, fn {client, attrs} ->
    {:ok, v} = Atelier.create_vehicule(Map.put(attrs, :client_id, client.id))
    v
  end)

[clio, duster, p308, yaris, berlingo, tesla, golf] = vehicules_inseres

interventions = [
  {clio,
   %{
     date: ~D[2026-09-12],
     type: :revision,
     kilometrage: 120_000,
     description: "Révision des 120 000 km",
     pieces: "Filtre à huile, filtre à air, huile 5W30",
     montant_euros: "289,90",
     statut: :paye
   }},
  {clio,
   %{
     date: ~D[2026-10-28],
     type: :pneus,
     kilometrage: 126_800,
     description: "Remplacement des 2 pneus avant",
     pieces: "2 × Michelin Energy Saver 195/65 R15",
     montant_euros: "218,00",
     statut: :facture
   }},
  {duster,
   %{
     date: ~D[2026-10-05],
     type: :vidange,
     kilometrage: 60_000,
     description: "Vidange et contrôle des niveaux",
     pieces: "Huile 5W40, joint de bouchon",
     montant_euros: "124,50",
     statut: :paye
   }},
  {p308,
   %{
     date: ~D[2026-11-02],
     type: :diagnostic,
     kilometrage: 94_500,
     description: "Voyant moteur allumé — diagnostic valise",
     pieces: "",
     montant_euros: "60,00",
     statut: :termine
   }},
  {p308,
   %{
     date: ~D[2026-11-04],
     type: :reparation,
     kilometrage: 94_700,
     description: "Remplacement de la vanne EGR",
     pieces: "Vanne EGR, joint",
     montant_euros: "487,30",
     statut: :en_cours
   }},
  {yaris,
   %{
     date: ~D[2026-08-21],
     type: :controle_technique,
     kilometrage: 40_100,
     description: "Passage au contrôle technique — favorable",
     montant_euros: "0",
     statut: :paye
   }},
  {berlingo,
   %{
     date: ~D[2026-10-15],
     type: :carrosserie,
     kilometrage: 210_400,
     description: "Reprise de l'aile avant droite",
     pieces: "Peinture, mastic",
     montant_euros: "740,00",
     statut: :devis
   }},
  {tesla,
   %{
     date: ~D[2026-09-30],
     type: :pneus,
     kilometrage: 36_000,
     description: "Permutation des pneus",
     montant_euros: "45,00",
     statut: :paye
   }},
  {golf,
   %{
     date: ~D[2026-11-05],
     type: :reparation,
     kilometrage: 105_500,
     description: "Plaquettes et disques avant",
     pieces: "Kit plaquettes + 2 disques",
     montant_euros: "356,80",
     statut: :en_cours
   }},
  {golf,
   %{
     date: ~D[2026-06-11],
     type: :revision,
     kilometrage: 100_000,
     description: "Grande révision 100 000 km",
     pieces: "Courroie de distribution, pompe à eau",
     montant_euros: "1 240,00",
     statut: :paye
   }}
]

Enum.each(interventions, fn {vehicule, attrs} ->
  {:ok, _} = Atelier.create_intervention(Map.put(attrs, :vehicule_id, vehicule.id))
end)

IO.puts("""

Jeu d'essai créé :
  #{Atelier.count_clients()} clients
  #{Atelier.count_vehicules()} véhicules
  #{Atelier.count_interventions()} interventions
  encaissé : #{Garage.Atelier.Intervention.formater_euros(Atelier.total_encaisse())}
""")
