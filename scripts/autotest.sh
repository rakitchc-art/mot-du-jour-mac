#!/bin/bash
# ============================================================================
#  autotest.sh — l'essai de l'appli fabriquée, sur un vrai Mac (ceux de GitHub).
#
#  1. Les planches : les looks possibles, dessinés par le vrai code.
#  2. L'appli lancée comme un double-clic (open), qui joue une partie scriptée
#     dans le vrai panneau ; l'écran entier est photographié quand elle le
#     demande (fichiers témoins etape-<nom> → capture-faite-<nom>).
#  Tout va dans sortie/captures. Échoue si la partie ne s'est pas jouée comme
#  prévu (resultat-autotest.txt doit dire REUSSI).
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

APP="$PWD/sortie/Mot du jour.app"
CAPT="$PWD/sortie/captures"
rm -rf "$CAPT"
mkdir -p "$CAPT"

echo "== les planches"
"$APP/Contents/MacOS/MotDuJour" --apercu "$CAPT" || { echo "les planches ont échoué"; exit 1; }

attendre() {   # attendre <fichier> <secondes>
  local n=0
  while [ ! -f "$1" ]; do
    sleep 0.5
    n=$((n + 1))
    if [ "$n" -ge $(( $2 * 2 )) ]; then return 1; fi
  done
  return 0
}

echo "== la partie scriptée"
open -n "$APP" --args --autotest "$CAPT"
for etape in panneau-ouvert stats; do
  if attendre "$CAPT/etape-$etape" 60; then
    sleep 0.4
    if screencapture -x "$CAPT/ecran-$etape.png"; then
      echo "écran photographié : $etape"
    else
      echo "screencapture a échoué ($etape)"
    fi
    touch "$CAPT/capture-faite-$etape"
  else
    echo "l'étape $etape n'est jamais arrivée"
    break
  fi
done
attendre "$CAPT/autotest-fini" 90 || echo "l'autotest n'a pas annoncé sa fin"
sleep 1
pkill -f "Mot du jour.app/Contents/MacOS/MotDuJour" || true

echo "== journal"
cat "$CAPT/journal-autotest.txt" 2>/dev/null || echo "(pas de journal)"
grep -qx "REUSSI" "$CAPT/resultat-autotest.txt" 2>/dev/null
