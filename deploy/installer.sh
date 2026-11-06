#!/bin/bash
#
# Installation de Garage en une commande.
#
#   curl -fsSLo /tmp/garage.sh https://raw.githubusercontent.com/N0AH-sve/Edouard_project/main/deploy/installer.sh
#   bash /tmp/garage.sh
#
# Pourquoi passer par le Terminal plutôt que par un double-clic :
# macOS marque tout fichier téléchargé par un navigateur d'un attribut
# « com.apple.quarantine », et refuse ensuite d'ouvrir un exécutable qui
# n'est pas signé par un développeur identifié chez Apple. curl ne pose
# pas cet attribut : rien n'est bloqué.
set -euo pipefail

DEPOT="N0AH-sve/Edouard_project"
ARCHIVE="garage-macos-arm64.zip"
URL="https://github.com/${DEPOT}/releases/latest/download/${ARCHIVE}"

bleu() { printf '\033[1;34m%s\033[0m\n' "$*"; }
gras() { printf '\n\033[1m%s\033[0m\n' "$*"; }
stop() { printf '\n\033[31mErreur : %s\033[0m\n\n' "$*" >&2; exit 1; }

clear
cat <<'BANNIERE'
================================================
   Installation de Garage
================================================

BANNIERE

# --- Vérifications ----------------------------------------------------------

[ "$(uname -s)" = "Darwin" ] || stop "cet installeur est prévu pour macOS."

if [ "$(uname -m)" != "arm64" ]; then
  stop "l'application est prévue pour les Mac à puce Apple (M1 à M4).
Ce Mac est de type « $(uname -m) ». Prévenez Noah."
fi

command -v curl >/dev/null || stop "curl est introuvable."
command -v unzip >/dev/null || stop "unzip est introuvable."

# --- Téléchargement ---------------------------------------------------------

travail="$(mktemp -d)"
trap 'rm -rf "$travail"' EXIT

gras "1/3  Téléchargement de la dernière version"
bleu "     $URL"

if ! curl -fL --progress-bar -o "$travail/$ARCHIVE" "$URL"; then
  stop "le téléchargement a échoué.

Vérifiez votre connexion. Si le problème persiste, c'est
peut-être qu'aucune version n'a encore été publiée —
prévenez Noah."
fi

taille=$(wc -c < "$travail/$ARCHIVE" | tr -d ' ')
[ "$taille" -gt 1000000 ] || stop "le fichier téléchargé est incomplet ($taille octets)."

# --- Extraction -------------------------------------------------------------

gras "2/3  Extraction"
unzip -q "$travail/$ARCHIVE" -d "$travail/extrait" \
  || stop "l'archive est illisible."

installeur="$(find "$travail/extrait" -name install.command -type f -print -quit)"
[ -n "$installeur" ] || stop "l'archive ne contient pas d'installeur."

chmod +x "$installeur"

# --- Installation -----------------------------------------------------------

gras "3/3  Installation"
echo

# Le script d'installation attend une touche à la fin : il a besoin du
# terminal, pas du tube. C'est pour cela que cette commande se lance par
# « bash fichier » et non par « curl | bash ».
bash "$installeur"
