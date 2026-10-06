#!/bin/bash
# ============================================================================
#  captures-notice.sh — les photos de la notice d'installation : ce que verra
#  son amie, sur un vrai Mac, si possible en français. Ce n'est pas une
#  épreuve : rien ici ne fait échouer la fabrication (le workflow le lance
#  avec continue-on-error), et les photos sont REGARDÉES avant d'être gardées.
#
#  1. le .dmg ouvert, comme après un double-clic dans Téléchargements ;
#  2. l'appli copiée dans Applications, marquée « téléchargée » comme le fait
#     le navigateur, puis ouverte : l'avertissement d'Apple ;
#  3. Réglages Système, Confidentialité et sécurité : « Ouvrir quand même ».
#  Il change la langue du Mac de GitHub : à lancer en DERNIER.
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

SORTIE="$PWD/sortie"
N="$SORTIE/notice"
rm -rf "$N"
mkdir -p "$N"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$SORTIE/Mot du jour.app/Contents/Info.plist")
NOM_DMG="Mot-du-jour-$VERSION.dmg"
INSTALLEE="/Applications/Mot du jour.app"
marque_telechargement() {   # comme Safari : l'attribut de quarantaine
  xattr -w com.apple.quarantine "0083;$(printf %x "$(date +%s)");Safari;" "$1"
}

# Le Mac en français, pour ce qui se lance à partir de maintenant.
defaults write -g AppleLanguages -array fr-FR fr en
defaults write -g AppleLocale -string fr_FR
killall CoreServicesUIAgent 2>/dev/null
killall Finder 2>/dev/null
killall "System Settings" 2>/dev/null
sleep 4

# 1. Le .dmg, depuis Téléchargements.
cp "$SORTIE/$NOM_DMG" "$HOME/Downloads/"
marque_telechargement "$HOME/Downloads/$NOM_DMG"
open "$HOME/Downloads/$NOM_DMG"
sleep 8
screencapture -x "$N/1-dmg-ouvert.png" && echo "photo : 1-dmg-ouvert"

# 2. Glissée dans Applications (on le fait pour elle), puis ouverte.
rm -rf "$INSTALLEE"
cp -R "/Volumes/Mot du jour/Mot du jour.app" /Applications/ || echo "copie depuis le .dmg impossible"
marque_telechargement "$INSTALLEE"
xattr -l "$INSTALLEE" | head -3
# EN ARRIÈRE-PLAN : `open` attend la fin du lancement, donc la réponse à
# l'avertissement — personne ne répond ici, il attendait sans fin (vu le 06/10).
open "$INSTALLEE" &
OUVERTURE=$!
sleep 7
screencapture -x "$N/2-avertissement.png" && echo "photo : 2-avertissement"

# 3. Réglages Système → Confidentialité et sécurité, section Sécurité.
open "x-apple.systempreferences:com.apple.preference.security?Security" &
sleep 9
screencapture -x "$N/3-reglages.png" && echo "photo : 3-reglages"

kill "$OUVERTURE" 2>/dev/null
hdiutil detach "/Volumes/Mot du jour" -force > /dev/null 2>&1 &
ls -la "$N"
