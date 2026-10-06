#!/bin/bash
# ============================================================================
#  epreuve-clavier.sh — le VRAI clavier, sur un vrai Mac. L'autotest dépose
#  ses touches directement dans l'appli ; il ne dit pas si, chez elle, ses
#  frappes arrivent bien au panneau — c'est macOS qui décide quelle appli les
#  reçoit (depuis macOS 14, une appli ne peut plus prendre la main de force).
#
#  Ici : une autre appli au premier plan (le Finder), un VRAI clic de souris
#  sur l'icône, puis de VRAIES frappes (« abces », Entrée) envoyées au clavier
#  de macOS. Réussi si le mot est arrivé dans le carnet du jeu.
#  Puis Échap doit fermer le panneau.
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

APP="$PWD/sortie/Mot du jour.app"
EP="$PWD/sortie/epreuve-clavier"
CARNET="$EP/carnet-essai/carnet.json"
rm -rf "$EP"
mkdir -p "$EP"
echec() { echo "ÉPREUVE RATÉE : $1"; pkill -f "Mot du jour.app/Contents/MacOS/MotDuJour"; exit 1; }

open -n "$APP" --args --epreuve-clavier "$EP"
PID=""
for i in $(seq 1 40); do
  PID=$(pgrep -f "Mot du jour.app/Contents/MacOS/MotDuJour" | head -1)
  [ -n "$PID" ] && break
  sleep 0.5
done
[ -n "$PID" ] || echec "l'appli ne démarre pas"
sleep 2

# Une autre appli au premier plan : c'est elle qui aurait les frappes si le
# panneau ne prenait pas la main.
osascript -e 'tell application "Finder" to activate'
sleep 1

POSITION=$(osascript scripts/position-icone.applescript "$PID")
echo "icône : $POSITION"
[ "$POSITION" != "introuvable" ] || echec "icône introuvable dans la barre des menus"
swift scripts/cliquer.swift $POSITION || echec "le clic n'a pas pu être fait"
sleep 1.5
screencapture -x "$EP/apres-clic.png" || true

osascript -e 'tell application "System Events" to keystroke "abces"' -e 'delay 0.4' \
          -e 'tell application "System Events" to key code 36'
sleep 1.5
screencapture -x "$EP/apres-frappe.png" || true

if [ -f "$CARNET" ] && grep -q '"mot" : "abces"' "$CARNET"; then
  echo "les frappes sont arrivées au jeu : « abces » est dans le carnet"
else
  echo "--- carnet"; cat "$CARNET" 2>/dev/null || echo "(pas de carnet)"
  echec "les vraies frappes ne sont pas arrivées au panneau"
fi

osascript -e 'tell application "System Events" to key code 53'
sleep 1
screencapture -x "$EP/apres-echap.png" || true
pkill -f "Mot du jour.app/Contents/MacOS/MotDuJour"
echo "ÉPREUVE DU VRAI CLAVIER RÉUSSIE"
