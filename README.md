# Garage

Application de gestion pour un garagiste indépendant : clients, véhicules,
historique d'interventions et archivage de PDF.

Auto-hébergée sur **un seul Mac**. Elle démarre à l'ouverture de session,
n'écoute que sur `127.0.0.1`, et les données ne quittent jamais la machine.

## Le modèle

Un garagiste ne suit pas des clients, il suit des véhicules :

```
client ──< véhicule ──< intervention
   └──────────┴─────────────┴──< document (PDF)
```

La recherche porte sur tout : nom, téléphone, ville, marque — et
l'immatriculation, qui est souvent la seule chose que le garagiste a sous
les yeux. Elle ignore les accents et les tirets (`benoit` trouve
« Benoît », `ab123cd` trouve `AB-123-CD`).

## Développement

Prérequis : Erlang/OTP 27 et Elixir 1.20.

```bash
mix setup
```

```bash
mix phx.server
```

L'application répond sur http://localhost:4000. Au premier lancement, elle
demande le profil du garagiste ; ensuite elle ouvre la liste des clients.

Jeu d'essai :

```bash
mix run priv/repo/seeds.exs
```

Avant de pousser :

```bash
mix precommit
```

## Installation sur le Mac du garagiste

Pousser un tag `v*` déclenche [la chaîne de publication](.github/workflows/release.yml) :
GitHub Actions compile sur un runner macOS une release auto-portante —
Erlang est embarqué, rien à installer sur la machine cible — et publie
`garage-macos-arm64.zip`. Le nom est fixe, sans numéro de version, pour
que l'URL `releases/latest/download/…` reste valable d'une version à
l'autre.

Sur son Mac, deux lignes dans le Terminal suffisent :

```bash
curl -fsSLo /tmp/garage.sh https://raw.githubusercontent.com/N0AH-sve/Edouard_project/main/deploy/installer.sh
```

```bash
bash /tmp/garage.sh
```

L'application démarre ensuite seule à chaque ouverture de session, une
icône est posée dans ses Applications, et une sauvegarde quotidienne part
dans iCloud Drive. Aucun mot de passe administrateur n'est demandé : tout
vit dans son dossier utilisateur.

### Pourquoi le Terminal et non un double-clic

macOS marque tout fichier enregistré par un navigateur d'un attribut
`com.apple.quarantine`, puis refuse d'ouvrir un exécutable qui n'est pas
signé avec un certificat Developer ID délivré par Apple et notarisé. Nos
binaires sont signés « ad-hoc » — assez pour qu'Apple Silicon accepte de
les exécuter, pas assez pour Gatekeeper.

`curl` ne pose pas cet attribut. L'installation par le Terminal ne
rencontre donc jamais le blocage, là où un double-clic sur une archive
téléchargée le rencontre presque toujours.

Pour qui a déjà l'archive sous la main — clé USB, copie locale —
[deploy/LISEZ-MOI.txt](deploy/LISEZ-MOI.txt) décrit la marche à suivre,
y compris le contournement si macOS bloque.

## Quelques partis pris

**SQLite**, pas PostgreSQL : un seul utilisateur, un seul fichier, aucun
serveur à maintenir, une sauvegarde qui tient dans une copie de fichier.

**Les montants en centimes entiers.** SQLite n'a pas de type décimal et les
flottants faussent les totaux de facture.

**Une colonne de recherche aplatie.** SQLite ne compare que l'ASCII :
`LOWER('Benoît')` rend `benoît`. On indexe donc une forme sans accent, en
deux variantes — espacée et compactée.

**Suppression refusée plutôt que cascade.** Supprimer un client qui a des
véhicules, ou un véhicule qui a un historique, échoue bruyamment. Des
années de dossiers ne doivent pas disparaître sur un clic.

**La date de naissance n'est pas modifiable** une fois saisie : elle
déclenche la page d'anniversaire, et une date qu'on peut changer n'est pas
un anniversaire.

**Les PDF sur le disque, pas en base.** La base ne retient qu'un chemin
relatif ; le nom du fichier est généré par l'application, jamais repris de
celui du navigateur.
