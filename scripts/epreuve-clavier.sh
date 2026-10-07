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
#  Puis Échap : seulement photographié (apres-echap.png), pas vérifié.
#
#  Et « Dire à Dova quand j'ai joué » (07/10) : ce vrai essai doit faire noter
#  le jour dans le registre — le VRAI serveur (serveur-activite/serveur.mjs),
#  lancé ici en local ; l'appli essayée est une copie dont l'adresse du
#  registre pointe sur lui. Le registre de Dova n'est jamais touché.
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

APP="$PWD/sortie/Mot du jour.app"
EP="$PWD/sortie/epreuve-clavier"
CARNET="$EP/carnet-essai/carnet.json"
rm -rf "$EP"
mkdir -p "$EP"
SERVEUR=""
TMPC=$(mktemp -d)
REGISTRE="$EP/registre-activite.jsonl"
JOURNAL="$HOME/Library/Logs/Mot du jour/journal.txt"
echec() {
  echo "ÉPREUVE RATÉE : $1"
  pkill -f "Mot du jour.app/Contents/MacOS/MotDuJour"
  [ -n "$SERVEUR" ] && kill "$SERVEUR" 2>/dev/null
  echo "--- journal (activité)"; grep "activité" "$JOURNAL" 2>/dev/null || echo "(rien)"
  echo "--- registre"; cat "$REGISTRE" 2>/dev/null || echo "(vide)"
  rm -rf "$TMPC"
  exit 1
}

# Le registre local, et la copie qui y écrit.
PORT=8791
MDJ_PORT=$PORT MDJ_REGISTRE="$REGISTRE" node serveur-activite/serveur.mjs > "$EP/serveur-activite.log" 2>&1 &
SERVEUR=$!
for i in $(seq 1 30); do curl -s -m 2 -o /dev/null "http://127.0.0.1:$PORT/sante" && break; sleep 0.5; done
curl -s -m 5 -o /dev/null -f "http://127.0.0.1:$PORT/sante" || echec "le registre local ne répond pas"
cp -R "$APP" "$TMPC/"
COPIE="$TMPC/Mot du jour.app"
/usr/libexec/PlistBuddy -c "Set :MDJActiviteURL http://127.0.0.1:$PORT/activite" \
                        -c "Add :NSAppTransportSecurity dict" \
                        -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" "$COPIE/Contents/Info.plist" \
  || echec "copie d'épreuve"
codesign --force --deep --sign - "$COPIE" > /dev/null 2>&1 || echec "signature de la copie d'épreuve"
defaults delete fr.dova.motdujour activiteJoursSignales > /dev/null 2>&1
defaults delete fr.dova.motdujour activiteCoupeeParElle > /dev/null 2>&1
rm -f "$JOURNAL"

open -n "$COPIE" --args --epreuve-clavier "$EP"
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

# Le jour joué doit arriver au registre (l'appli regarde toutes les 20 s).
JOUR=$(date +%F)
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$COPIE/Contents/Info.plist")
n=0
until grep -q "\"jour\":\"$JOUR\"" "$REGISTRE" 2>/dev/null; do
  sleep 1; n=$((n + 1))
  [ "$n" -ge 45 ] && echec "le jour joué ($JOUR) n'est pas arrivé au registre en 45 s"
done
[ "$(grep -c . "$REGISTRE")" -eq 1 ] || echec "le registre devrait avoir UNE ligne"
grep -q "\"version\":\"$VERSION\"" "$REGISTRE" || echec "le registre n'a pas la version $VERSION"
defaults read fr.dova.motdujour activiteJoursSignales 2>/dev/null | grep -q "$JOUR" \
  || echec "l'appli n'a pas retenu que $JOUR est signalé (elle le renverrait)"
echo "registre : $(cat "$REGISTRE")"
grep "activité" "$JOURNAL"

pkill -f "Mot du jour.app/Contents/MacOS/MotDuJour"
kill "$SERVEUR" 2>/dev/null
rm -rf "$TMPC"
echo "ÉPREUVE DU VRAI CLAVIER RÉUSSIE (et le jour joué est arrivé au registre)"
