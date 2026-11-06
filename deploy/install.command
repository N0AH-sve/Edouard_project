#!/bin/bash
# Installeur de l'application Garage — à double-cliquer.
# Tout se fait dans le dossier utilisateur : aucun mot de passe administrateur.
set -euo pipefail

APP_NAME="Garage"
APP_ID="com.edouard.garage"
PORT="4000"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/Applications/$APP_NAME"
DATA_DIR="$HOME/Library/Application Support/$APP_NAME"
AGENTS_DIR="$HOME/Library/LaunchAgents"
ENV_FILE="$DATA_DIR/env.sh"
LOG_DIR="$HOME/Library/Logs/$APP_NAME"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
die() { printf '\n\033[31mErreur : %s\033[0m\n' "$*" >&2; read -rp "Appuyez sur Entrée pour fermer." _; exit 1; }

clear
cat <<BANNER
================================================
   Installation de $APP_NAME
================================================
BANNER

[ "$(uname -s)" = "Darwin" ] || die "Cet installeur est destiné à macOS."

# --- Architecture ------------------------------------------------------------
# On interroge le binaire lui-même plutôt que le nom du dossier : celui-ci
# peut avoir été renommé, et l'erreur « Bad CPU type » qui suivrait serait
# incompréhensible.
arch="$(uname -m)"
[ -x "$HERE/garage/bin/garage" ] || die "Fichiers de l'application introuvables dans $HERE.
Décompressez l'archive avant de lancer l'installeur."

moteur="$(find "$HERE/garage" -name beam.smp -type f -print -quit 2>/dev/null || true)"

if [ -n "$moteur" ]; then
  decrit="$(file -b "$moteur" 2>/dev/null || true)"

  # L'application n'est compilée que pour Apple Silicon.
  case "$arch:$decrit" in
    arm64:*arm64*|arm64:*universal*) : ;;
    *)
      die "Ce Mac n'est pas compatible.

L'application est prévue pour les Mac à puce Apple
(M1, M2, M3, M4). Ce Mac est de type « $arch ».

Prévenez Noah : une version adaptée doit être compilée."
      ;;
  esac
fi

# --- Quarantaine Gatekeeper --------------------------------------------------
say "1/7  Déblocage des fichiers téléchargés"
xattr -dr com.apple.quarantine "$HERE" 2>/dev/null || true

# --- Arrêt d'une version déjà installée --------------------------------------
say "2/7  Arrêt de la version précédente, s'il y en a une"
for lbl in "$APP_ID" "$APP_ID.backup"; do
  launchctl bootout "gui/$(id -u)/$lbl" 2>/dev/null || true
done

# --- Copie -------------------------------------------------------------------
say "3/7  Installation de l'application"
mkdir -p "$INSTALL_DIR" "$DATA_DIR/uploads" "$LOG_DIR"
chmod 700 "$DATA_DIR"
rm -rf "$INSTALL_DIR/garage"
cp -R "$HERE/garage" "$INSTALL_DIR/garage"
cp "$HERE/backup.sh" "$INSTALL_DIR/backup.sh"
chmod +x "$INSTALL_DIR/backup.sh"

# --- Secrets : générés une seule fois, conservés entre les mises à jour ------
say "4/7  Configuration"
if [ ! -f "$ENV_FILE" ]; then
  umask 077
  cat > "$ENV_FILE" <<ENV
# Généré à l'installation — ne pas partager ce fichier.
export SECRET_KEY_BASE="$(head -c 48 /dev/urandom | base64 | tr -d '\n=' )$(head -c 24 /dev/urandom | base64 | tr -d '\n=')"
export RELEASE_COOKIE="$(head -c 32 /dev/urandom | base64 | tr -d '\n=')"
ENV
  chmod 600 "$ENV_FILE"
  echo "    Nouveaux secrets générés."
else
  echo "    Secrets existants conservés."
fi
# shellcheck source=/dev/null
. "$ENV_FILE"

export DATABASE_PATH="$DATA_DIR/garage.db"
export UPLOADS_DIR="$DATA_DIR/uploads"
export PHX_HOST="localhost"
export PORT="$PORT"
export PHX_SERVER="true"

# --- Migrations --------------------------------------------------------------
say "5/7  Préparation de la base de données"
"$INSTALL_DIR/garage/bin/garage" eval "Garage.Release.migrate" \
  || die "La migration de la base a échoué. Consultez $LOG_DIR."

# --- LaunchAgents ------------------------------------------------------------
say "6/7  Démarrage automatique à l'ouverture de session"
mkdir -p "$AGENTS_DIR"
for f in "$APP_ID.plist" "$APP_ID.backup.plist"; do
  sed -e "s|@@HOME@@|$HOME|g" \
      -e "s|@@INSTALL_DIR@@|$INSTALL_DIR|g" \
      -e "s|@@DATA_DIR@@|$DATA_DIR|g" \
      -e "s|@@LOG_DIR@@|$LOG_DIR|g" \
      -e "s|@@PORT@@|$PORT|g" \
      "$HERE/$f" > "$AGENTS_DIR/$f"
done
for lbl in "$APP_ID" "$APP_ID.backup"; do
  launchctl bootstrap "gui/$(id -u)" "$AGENTS_DIR/$lbl.plist" \
    || die "Impossible d'enregistrer le service $lbl."
done

# --- Raccourci dans le Dock --------------------------------------------------
say "7/7  Création du raccourci"
LAUNCHER="$HOME/Applications/$APP_NAME.app"
rm -rf "$LAUNCHER"
mkdir -p "$LAUNCHER/Contents/MacOS"
cat > "$LAUNCHER/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$APP_ID.launcher</string>
  <key>CFBundleExecutable</key><string>launcher</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
cat > "$LAUNCHER/Contents/MacOS/launcher" <<LAUNCH
#!/bin/bash
# Attend que le serveur réponde, puis ouvre le navigateur.
for _ in \$(seq 1 30); do
  if curl -fsS -o /dev/null "http://127.0.0.1:$PORT/"; then break; fi
  sleep 0.5
done
open "http://127.0.0.1:$PORT/"
LAUNCH
chmod +x "$LAUNCHER/Contents/MacOS/launcher"

# --- Vérification ------------------------------------------------------------
say "Vérification du démarrage"
ok=""
for _ in $(seq 1 40); do
  if curl -fsS -o /dev/null "http://127.0.0.1:$PORT/"; then ok="yes"; break; fi
  sleep 0.5
done

if [ -n "$ok" ]; then
  cat <<DONE

================================================
   Installation réussie
================================================

  $APP_NAME démarre maintenant tout seul à chaque
  ouverture de session.

  Pour l'ouvrir : $HOME/Applications/$APP_NAME.app
  (glissez-la dans le Dock pour la garder à portée)

  Vos données : $DATA_DIR
  Sauvegarde automatique chaque jour dans iCloud Drive.

DONE
  open "http://127.0.0.1:$PORT/"
else
  cat <<FAIL

L'application est installée mais ne répond pas encore.
Vérifiez le journal : $LOG_DIR/erreurs.log

FAIL
fi
read -rp "Appuyez sur Entrée pour fermer cette fenêtre." _
