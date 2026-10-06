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

# 6. Le .dmg de la première installation : l'appli, et un raccourci vers
#    Applications pour l'y glisser.
DMG="$SORTIE/dmg"
mkdir -p "$DMG"
cp -R "$APP" "$DMG/"
ln -s /Applications "$DMG/Applications"
hdiutil create -volname "Mot du jour" -srcfolder "$DMG" -ov -format UDZO "$SORTIE/Mot-du-jour-$VERSION.dmg"
rm -rf "$DMG"

# 7. L'effet, pas le code de retour : l'appli emballée dit bien sa version.
LUE=$("$APP/Contents/MacOS/MotDuJour" --version)
if [ "$LUE" != "$VERSION" ]; then
  echo "L'appli emballée dit « $LUE », attendu « $VERSION »."
  exit 1
fi
echo "== fabriqué :"
ls -la "$SORTIE"
