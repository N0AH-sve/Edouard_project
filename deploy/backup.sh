#!/bin/bash
# Sauvegarde quotidienne de la base et des PDF, lancée par launchd.
# Un garage sans son fichier clients, c'est une activité à l'arrêt :
# ce script n'est pas optionnel.
set -euo pipefail

DATA_DIR="${DATA_DIR:-$HOME/Library/Application Support/Garage}"
DB="$DATA_DIR/garage.db"
UPLOADS="$DATA_DIR/uploads"
RETENTION_DAYS=30

ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
if [ -d "$ICLOUD" ]; then
  DEST="$ICLOUD/Garage-Sauvegardes"
else
  # Pas d'iCloud Drive activé : on retombe sur Documents, que Time Machine couvre.
  DEST="$HOME/Documents/Garage-Sauvegardes"
fi

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

[ -f "$DB" ] || { log "Aucune base à sauvegarder ($DB) — rien à faire."; exit 0; }

stamp="$(date '+%Y-%m-%d')"
target="$DEST/$stamp"
mkdir -p "$target"

# VACUUM INTO produit un instantané cohérent même si l'application écrit
# pendant la copie. Un simple « cp » du fichier .db peut capturer une
# transaction à moitié écrite et donner une sauvegarde corrompue.
log "Instantané de la base"
/usr/bin/sqlite3 "file:$DB?mode=ro" "VACUUM INTO '$target/garage.db'" \
  || { log "ÉCHEC de l'instantané SQLite"; exit 1; }

# Contrôle d'intégrité : une sauvegarde jamais vérifiée n'est pas une sauvegarde.
check="$(/usr/bin/sqlite3 "$target/garage.db" 'PRAGMA integrity_check;')"
if [ "$check" != "ok" ]; then
  log "ÉCHEC du contrôle d'intégrité : $check"
  mv "$target/garage.db" "$target/garage.db.SUSPECT"
  exit 1
fi
log "Base sauvegardée et vérifiée ($(du -h "$target/garage.db" | cut -f1))"

if [ -d "$UPLOADS" ]; then
  log "Copie des PDF"
  mkdir -p "$target/uploads"
  /usr/bin/rsync -a --delete "$UPLOADS/" "$target/uploads/"
  log "PDF sauvegardés ($(find "$target/uploads" -type f | wc -l | tr -d ' ') fichiers)"
fi

# Rotation : on garde RETENTION_DAYS jours, et toujours au moins la dernière.
log "Rotation (conservation : $RETENTION_DAYS jours)"
cd "$DEST"
# shellcheck disable=SC2012
ls -1d 20*-*-* 2>/dev/null | sort | head -n -1 | while read -r d; do
  age_days=$(( ( $(date +%s) - $(stat -f %m "$d") ) / 86400 ))
  if [ "$age_days" -gt "$RETENTION_DAYS" ]; then
    log "  suppression de $d (${age_days} jours)"
    rm -rf "$d"
  fi
done

log "Sauvegarde terminée → $target"
