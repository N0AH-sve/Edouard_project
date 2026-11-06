#!/bin/bash
#
# Diagnostic de Garage. Ne modifie rien, se contente de regarder.
#
#   curl -fsSLo /tmp/diag.sh https://raw.githubusercontent.com/N0AH-sve/Edouard_project/main/deploy/diagnostic.sh
#   bash /tmp/diag.sh
#
# Le résultat est enregistré dans un fichier à envoyer à Noah.

APP_ID="com.edouard.garage"
PORT="4000"
INSTALL_DIR="$HOME/Applications/Garage"
DATA_DIR="$HOME/Library/Application Support/Garage"
LOG_DIR="$HOME/Library/Logs/Garage"
RAPPORT="$HOME/Desktop/diagnostic-garage.txt"

titre() { printf '\n========== %s ==========\n' "$*"; }

{
  echo "Diagnostic Garage — $(date)"
  echo "macOS $(sw_vers -productVersion 2>/dev/null) / $(uname -m)"

  titre "1. Fichiers installés"
  for f in "$INSTALL_DIR/garage/bin/garage" "$DATA_DIR/env.sh" "$DATA_DIR/garage.db" \
           "$HOME/Library/LaunchAgents/$APP_ID.plist"; do
    [ -e "$f" ] && echo "  présent : $f" || echo "  MANQUANT : $f"
  done

  titre "2. Le service est-il enregistré ?"
  launchctl print "gui/$(id -u)/$APP_ID" 2>&1 \
    | grep -E 'state|pid|last exit|program|path =' | head -20 \
    || echo "  service non enregistré auprès de launchd"

  titre "3. Quelque chose écoute-t-il sur le port $PORT ?"
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || echo "  personne n'écoute sur $PORT"

  titre "4. Journal d'erreurs (50 dernières lignes)"
  if [ -f "$LOG_DIR/erreurs.log" ]; then
    tail -50 "$LOG_DIR/erreurs.log"
  else
    echo "  aucun fichier $LOG_DIR/erreurs.log"
  fi

  titre "5. Journal applicatif (30 dernières lignes)"
  if [ -f "$LOG_DIR/application.log" ]; then
    tail -30 "$LOG_DIR/application.log"
  else
    echo "  aucun fichier $LOG_DIR/application.log"
  fi

  titre "6. Démarrage manuel (la vraie erreur apparaît ici)"
  # On lance l'application à la main, au premier plan, avec le même
  # environnement que le service : c'est le seul moyen de voir le
  # message que launchd avale.
  if [ -x "$INSTALL_DIR/garage/bin/garage" ] && [ -f "$DATA_DIR/env.sh" ]; then
    (
      . "$DATA_DIR/env.sh"
      export PHX_SERVER=true PHX_HOST=localhost PORT="$PORT"
      export DATABASE_PATH="$DATA_DIR/garage.db"
      export UPLOADS_DIR="$DATA_DIR/uploads"
      # 15 secondes suffisent : soit il démarre, soit il a déjà échoué.
      "$INSTALL_DIR/garage/bin/garage" eval 'IO.puts("DEMARRAGE OK : la machine virtuelle se lance")' 2>&1 | tail -30
    )
  else
    echo "  impossible : fichiers manquants"
  fi

  titre "7. Quarantaine restante sur les binaires"
  xattr -lr "$INSTALL_DIR/garage" 2>/dev/null | grep -c quarantine \
    | xargs -I{} echo "  fichiers encore en quarantaine : {}"

  titre "Fin"
} 2>&1 | tee "$RAPPORT"

echo
echo "================================================"
echo "  Rapport enregistré sur votre Bureau :"
echo "      diagnostic-garage.txt"
echo "  Envoyez ce fichier à Noah."
echo "================================================"
