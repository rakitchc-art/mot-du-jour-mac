#!/bin/bash
# ============================================================================
#  publier-release.sh — sur un Mac de GitHub, pour une étiquette vX.Y.Z :
#  1. signe l'archive avec la clé des secrets du dépôt (et vérifie la
#     signature contre la clé que l'appli embarque) ;
#  2. met la version en ligne comme « préversion » : invisible des applis
#     installées (elles ne lisent que la dernière version) ;
#  3. demande à l'APPLI ELLE-MÊME de juger cette préversion en ligne
#     (--controle-publication) : lisible, signée par la bonne clé, archive saine ;
#  4. seulement alors, la rend « dernière version » — sinon la retire.
#  Lancé par le workflow, jamais à la main (scripts/Publier.ps1 pose l'étiquette).
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

TAG="$1"
VERSION="${TAG#v}"
APP="sortie/Mot du jour.app"
DEPOT="$GITHUB_REPOSITORY"
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
  "sortie/Mot-du-jour.dmg" "sortie/Mot-du-jour-$VERSION.zip" "sortie/Mot-du-jour-$VERSION.zip.sig" \
  --repo "$DEPOT" --title "Mot du jour $VERSION" --notes-file "$NOTES" --verify-tag --prerelease

# L'appli juge la préversion en ligne, par son adresse d'étiquette.
CONTROLE="$PWD/sortie/controle-publication"
ADRESSE="https://api.github.com/repos/$DEPOT/releases/tags/$TAG"
for essai in 1 2 3 4 5 6; do
  rm -rf "$CONTROLE"
  # Avec le jeton du job : sans lui, l'API refuse (403) les questions sans
  # compte quand les Mac de GitHub ont épuisé leurs 60 par heure (06/10).
  MDJ_JETON_CONTROLE="$GH_TOKEN" "$APP/Contents/MacOS/MotDuJour" --controle-publication "$CONTROLE" "$ADRESSE" || true
  echo "contrôle $essai : $(cat "$CONTROLE/resultat.txt" 2>/dev/null || echo 'pas de résultat')"
  if grep -qx "ACCEPTEE $VERSION" "$CONTROLE/resultat.txt" 2>/dev/null; then
    gh release edit "$TAG" --repo "$DEPOT" --prerelease=false --latest
    echo "La publication $TAG est acceptée par l'appli, et devenue la dernière version."
    exit 0
  fi
  sleep 10
done
echo "L'appli n'accepte pas la publication : elle est retirée (l'étiquette reste ; monter la version)."
gh release delete "$TAG" --repo "$DEPOT" --yes
exit 1
