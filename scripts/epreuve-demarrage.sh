#!/bin/bash
# ============================================================================
#  epreuve-demarrage.sh — « Ouvrir au démarrage du Mac », éprouvé sur un vrai
#  Mac : l'appli installée dans /Applications (comme chez elle) s'inscrit
#  comme à son premier lancement, constate que macOS la tient pour active,
#  puis se désinscrit. Une appli signée « ad hoc » peut se faire refuser
#  l'inscription, ou la voir mise « en attente d'autorisation » : sans cette
#  épreuve, on ne l'apprendrait qu'à son premier redémarrage, icône disparue.
#  Ce que l'épreuve ne fait pas : redémarrer le Mac.
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

APP="$PWD/sortie/Mot du jour.app"
EP="$PWD/sortie/epreuve-demarrage"
INSTALLEE="/Applications/Mot du jour.app"
rm -rf "$EP"
mkdir -p "$EP"
rm -rf "$INSTALLEE"
cp -R "$APP" "$INSTALLEE"

open -n "$INSTALLEE" --args --epreuve-demarrage "$EP"
n=0
while [ ! -f "$EP/resultat.txt" ]; do
  sleep 0.5
  n=$((n + 1))
  if [ "$n" -ge 80 ]; then echo "ÉPREUVE RATÉE : pas de résultat en 40 s"; rm -rf "$INSTALLEE"; exit 1; fi
done
cat "$EP/resultat.txt"
rm -rf "$INSTALLEE"
grep -q "^REUSSI" "$EP/resultat.txt"
