#!/bin/bash
# ============================================================================
#  construire-app.sh — fabrique « Mot du jour.app », son archive .zip (pour les
#  mises à jour) et son .dmg (pour la première installation), dans sortie/.
#
#  Tourne sur un Mac : les Mac de GitHub (.github/workflows/fabriquer.yml).
#  La version n'est écrite qu'à UN endroit : Ressources/Info.plist.
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

PLIST="Ressources/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
SORTIE="$PWD/sortie"
APP="$SORTIE/Mot du jour.app"
echo "== Mot du jour $VERSION"

rm -rf "$SORTIE"
mkdir -p "$SORTIE"

# 1. Le programme, pour les deux familles de Mac : puce Apple et Intel.
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/MotDuJour"
lipo -info "$BIN"
lipo "$BIN" -verify_arch arm64 x86_64

# 2. L'icône de l'appli, dessinée par l'appli elle-même.
"$BIN" --icone "$SORTIE/AppIcon.iconset"
iconutil -c icns "$SORTIE/AppIcon.iconset" -o "$SORTIE/AppIcon.icns"

# 3. Le paquet .app.
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MotDuJour"
cp "$PLIST" "$APP/Contents/Info.plist"
# Le numéro de fabrication suit la version (une seule source : CFBundleShortVersionString).
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
cp "$SORTIE/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp CREDITS.md LICENSE "$APP/Contents/Resources/"
plutil -lint "$APP/Contents/Info.plist"

# 4. La signature « ad hoc » (sans compte Apple) : obligatoire pour tourner sur
#    un Mac à puce Apple. Elle n'enlève PAS l'avertissement de la première
#    ouverture : il faut pour ça un compte développeur Apple (99 € par an).
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

# 5. L'archive des mises à jour : ditto garde les droits et la signature.
( cd "$SORTIE" && ditto -c -k --sequesterRsrc --keepParent "Mot du jour.app" "Mot-du-jour-$VERSION.zip" )

# 6. Le .dmg de la première installation : l'appli, un raccourci vers
#    Applications pour l'y glisser, et une fenêtre mise en page (fond avec une
#    flèche). Son nom n'a PAS de numéro : le lien de téléchargement de la
#    notice (…/releases/latest/download/Mot-du-jour.dmg) reste le même à
#    chaque version.
DMG="$SORTIE/dmg"
mkdir -p "$DMG/.fond"
cp -R "$APP" "$DMG/"
ln -s /Applications "$DMG/Applications"
"$BIN" --fond-dmg "$SORTIE/fond"
tiffutil -cathidpicheck "$SORTIE/fond/fond.png" "$SORTIE/fond/fond@2x.png" -out "$DMG/.fond/fond.tiff"
hdiutil create -volname "Mot du jour" -srcfolder "$DMG" -ov -format UDRW "$SORTIE/brouillon.dmg"
ATTACHE=$(hdiutil attach -readwrite -noverify -noautoopen "$SORTIE/brouillon.dmg")
MONTAGE=$(echo "$ATTACHE" | grep -o '/Volumes/.*$' | head -1)
DISQUE=$(echo "$ATTACHE" | grep -o '^/dev/disk[0-9]*' | head -1)
echo "monté : $MONTAGE ($DISQUE)"
# La mise en page passe par le Finder : 60 s au plus, et sans elle le .dmg
# reste bon (fenêtre simple) — on le dit, on ne s'arrête pas.
osascript scripts/mettre-en-page-dmg.applescript "Mot du jour" > "$SORTIE/mise-en-page-dmg.txt" 2>&1 &
PAGE=$!
for i in $(seq 1 120); do kill -0 "$PAGE" 2>/dev/null || break; sleep 0.5; done
if kill -0 "$PAGE" 2>/dev/null; then kill "$PAGE"; echo "mise en page du .dmg : délai dépassé, fenêtre simple"; fi
echo "mise en page du .dmg : $(cat "$SORTIE/mise-en-page-dmg.txt")"
[ -f "$MONTAGE/.DS_Store" ] && echo "mise en page enregistrée (.DS_Store présent)" || echo "pas de .DS_Store : fenêtre simple"
sync
# Le démontage, par le DISQUE et en plusieurs essais : juste après la mise en
# page, le Finder tient parfois encore le volume (« Resource busy », passage
# du 06/10) — et un premier essai à moitié réussi fait disparaître le chemin
# /Volumes/… que le second visait.
DEMONTE=0
for essai in 1 2 3 4 5; do
  # Déjà parti (un essai précédent l'a lâché en partie) : c'est fait.
  # (Lu d'abord : `grep -q` dans un tuyau, sous pipefail, peut faire croire
  # « déjà parti » quand hdiutil reçoit SIGPIPE.)
  INFO=$(hdiutil info)
  if ! grep -q "^$DISQUE[[:space:]]" <<< "$INFO"; then DEMONTE=1; break; fi
  if hdiutil detach "$DISQUE" > /dev/null 2>&1; then DEMONTE=1; break; fi
  echo "démontage, essai $essai : le volume est encore tenu"
  sleep 2
done
if [ "$DEMONTE" -eq 0 ]; then
  hdiutil detach -force "$DISQUE" || { echo "le .dmg ne se démonte pas"; exit 1; }
fi
hdiutil convert "$SORTIE/brouillon.dmg" -format UDZO -ov -o "$SORTIE/Mot-du-jour.dmg"
rm -rf "$DMG" "$SORTIE/brouillon.dmg"

# 7. L'effet, pas le code de retour : l'appli emballée dit bien sa version.
LUE=$("$APP/Contents/MacOS/MotDuJour" --version)
if [ "$LUE" != "$VERSION" ]; then
  echo "L'appli emballée dit « $LUE », attendu « $VERSION »."
  exit 1
fi
echo "== fabriqué :"
ls -la "$SORTIE"
