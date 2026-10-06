#!/bin/bash
# ============================================================================
#  publier-release.sh — sur un Mac de GitHub, pour une étiquette vX.Y.Z :
#  signe l'archive avec la clé des secrets du dépôt, crée la publication, puis
#  demande à l'APPLI ELLE-MÊME de juger la publication en ligne
#  (--controle-publication) : lisible, signée par la bonne clé, archive saine.
#  Lancé par le workflow, jamais à la main (scripts/Publier.ps1 pose l'étiquette).
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

TAG="$1"
VERSION="${TAG#v}"
APP="sortie/Mot du jour.app"
LUE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
if [ "$LUE" != "$VERSION" ]; then
  echo "L'étiquette $TAG ne correspond pas à la version de l'appli ($LUE) : rien n'est publié."
  exit 1
fi
NOTES="notes/$TAG.md"
if [ ! -f "$NOTES" ]; then
  echo "Les notes de version manquent ($NOTES) : rien n'est publié."
  exit 1
fi
CLE=$(/usr/libexec/PlistBuddy -c "Print :MDJMiseAJourCle" "$APP/Contents/Info.plist")
node scripts/signer-archive.js "sortie/Mot-du-jour-$VERSION.zip" env:MAJ_CLE_PRIVEE "$CLE"

gh release create "$TAG" \
  "sortie/Mot-du-jour-$VERSION.dmg" "sortie/Mot-du-jour-$VERSION.zip" "sortie/Mot-du-jour-$VERSION.zip.sig" \
  --repo "$GITHUB_REPOSITORY" --title "Mot du jour $VERSION" --notes-file "$NOTES" --verify-tag

# L'effet, pas le code de retour : l'appli juge la publication en ligne.
CONTROLE="$PWD/sortie/controle-publication"
for essai in 1 2 3 4 5 6; do
  rm -rf "$CONTROLE"
  "$APP/Contents/MacOS/MotDuJour" --controle-publication "$CONTROLE" || true
  echo "contrôle $essai : $(cat "$CONTROLE/resultat-maj.txt" 2>/dev/null || echo 'pas de résultat')"
  if grep -q "^ACCEPTEE $VERSION" "$CONTROLE/resultat-maj.txt" 2>/dev/null; then
    echo "La publication $TAG est acceptée par l'appli."
    exit 0
  fi
  sleep 10
done
echo "L'appli n'accepte pas la publication en ligne."
exit 1
