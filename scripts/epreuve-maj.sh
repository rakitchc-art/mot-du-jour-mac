#!/bin/bash
# ============================================================================
#  epreuve-maj.sh — la mise à jour automatique, éprouvée EN VRAI sur un Mac
#  (ceux de GitHub), par le chemin de TOUS LES JOURS : l'appli installée dans
#  /Applications et marquée « téléchargée puis autorisée » (comme après
#  « Ouvrir quand même »), lancée comme un double-clic ; ses dossiers
#  ordinaires (Application Support, Caches, Logs) ; sa minuterie ; la pose ;
#  la relance SANS argument ; le bilan écrit par la neuve dans son journal
#  ordinaire. Seules l'adresse des publications (servies par la machine
#  elle-même) et la clé (jetable) changent.
#
#    A. une signature FAUSSE : rien ne bouge ;
#    B. la bonne : la neuve tourne, la sauvegarde de l'ancienne est effacée ;
#    C. une pose qui RATE (appli installée verrouillée) : l'ancienne reste,
#       la version est refusée pour toujours — pas de boucle.
#
#  L'autorisation des adresses locales (http://127.0.0.1) est ajoutée aux
#  COPIES d'épreuve, jamais à l'appli livrée.
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

SORTIE="$PWD/sortie"
APP="$SORTIE/Mot du jour.app"
EP="$SORTIE/epreuve-maj"
INSTALLEE="/Applications/Mot du jour.app"
PORT=8765
NEUVE_V="99.0.0"
SERVEUR=""
SUPPORT="$HOME/Library/Application Support/Mot du jour"
LOGS="$HOME/Library/Logs/Mot du jour"
JOURNAL="$LOGS/journal.txt"
TRAVAIL="$HOME/Library/Caches/fr.dova.motdujour"
rm -rf "$EP"
mkdir -p "$EP/serveur/faux" "$EP/neuve"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")

arreter_appli() { pkill -f "Mot du jour.app/Contents/MacOS/MotDuJour" 2>/dev/null; sleep 1; }
nettoyer() { arreter_appli; rm -rf "$SUPPORT" "$TRAVAIL" "$LOGS"; }
echec() {
  echo "ÉPREUVE RATÉE : $1"
  for f in "$EP/a/resultat.txt" "$JOURNAL" "$EP/serveur.log"; do
    [ -f "$f" ] && { echo "--- $f"; cat "$f"; }
  done
  [ -n "$SERVEUR" ] && kill "$SERVEUR" 2>/dev/null
  chflags -R nouchg "$INSTALLEE" 2>/dev/null
  rm -f "$EP/cle/cle-maj-privee.pem"   # jetable, mais jamais dans une pièce jointe publique
  exit 1
}
attendre_fichier() {   # attendre_fichier <fichier> <secondes>
  local n=0
  while [ ! -f "$1" ]; do
    sleep 0.5; n=$((n + 1))
    if [ "$n" -ge $(( $2 * 2 )) ]; then return 1; fi
  done
}
attendre_ligne() {   # attendre_ligne <motif> <secondes> : dans le journal ordinaire
  local n=0
  until grep -q "$1" "$JOURNAL" 2>/dev/null; do
    sleep 0.5; n=$((n + 1))
    if [ "$n" -ge $(( $2 * 2 )) ]; then return 1; fi
  done
}
version_installee() { /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INSTALLEE/Contents/Info.plist"; }
autoriser_local() {   # sur une copie d'épreuve seulement
  /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" \
                          -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" "$1/Contents/Info.plist"
  codesign --force --deep --sign - "$1"
}
preparer_dmg() {   # un .dmg comme celui qu'elle télécharge, avec la copie d'épreuve
  rm -rf "$EP/dmg-src"
  mkdir -p "$EP/dmg-src"
  cp -R "$APP" "$EP/dmg-src/"
  autoriser_local "$EP/dmg-src/Mot du jour.app" > /dev/null 2>&1 || echec "copie d'épreuve"
  ln -s /Applications "$EP/dmg-src/Applications"
  hdiutil create -volname "Mot du jour epreuve" -srcfolder "$EP/dmg-src" -ov -format UDZO "$EP/epreuve.dmg" > /dev/null \
    || echec "fabrication du .dmg d'épreuve"
  xattr -w com.apple.quarantine "0083;$(printf %x "$(date +%s)");Safari;" "$EP/epreuve.dmg"
}
installer() {   # comme ELLE : le .dmg téléchargé ouvert, l'appli glissée par le FINDER
  # (mesuré le 06/10 : posée par `cp` avec la marque de téléchargement, macOS
  # l'isole — elle tourne depuis …/AppTranslocation/… et ne peut pas se mettre
  # à jour. La question est de savoir ce qu'il fait d'une appli glissée par le
  # Finder, comme elle le fera.)
  chflags -R nouchg "$INSTALLEE" 2>/dev/null
  rm -rf "$INSTALLEE"
  hdiutil attach -noautoopen "$EP/epreuve.dmg" > "$EP/attache.txt" || echec "montage du .dmg d'épreuve"
  VOL=$(grep -o '/Volumes/.*$' "$EP/attache.txt" | head -1)
  osascript -e "tell application \"Finder\" to duplicate (POSIX file \"$VOL/Mot du jour.app\" as alias) to (POSIX file \"/Applications\" as alias) with replacing" \
    > /dev/null || echec "copie par le Finder"
  hdiutil detach "$VOL" -force > /dev/null 2>&1
  [ -d "$INSTALLEE" ] || echec "le Finder n'a rien posé dans /Applications"
  Q=$(xattr -p com.apple.quarantine "$INSTALLEE" 2>/dev/null)
  echo "marque posée par le Finder : ${Q:-aucune}"
  # « Ouvrir quand même » : le drapeau 0x40 (ouverte avec son accord) s'ajoute
  # à ceux que le Finder a posés.
  if [ -n "$Q" ]; then
    DRAPEAUX=$(printf "%04x" $(( 0x${Q%%;*} | 0x40 )))
    xattr -w com.apple.quarantine "$DRAPEAUX;${Q#*;}" "$INSTALLEE"
    echo "marque après « Ouvrir quand même » : $(xattr -p com.apple.quarantine "$INSTALLEE")"
  fi
}
lancer() {   # lancer <dossier du résultat> <publication> : comme un double-clic
  open -n "$INSTALLEE" --args --epreuve-maj "$1" "http://127.0.0.1:$PORT/$2" "$CLE" &
}

# 1. Une clé d'épreuve, jetable.
node scripts/creer-cle.js "$EP/cle" > /dev/null || echec "clé d'épreuve"
CLE=$(tr -d '\n' < "$EP/cle/cle-maj-publique.txt")

# 2. La « version suivante » : la même appli, numéro $NEUVE_V, re-signée ad hoc.
cp -R "$APP" "$EP/neuve/"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEUVE_V" "$EP/neuve/Mot du jour.app/Contents/Info.plist"
autoriser_local "$EP/neuve/Mot du jour.app" > /dev/null 2>&1 || echec "signature de code de la neuve"
ZIP="Mot-du-jour-$NEUVE_V.zip"
( cd "$EP/neuve" && ditto -c -k --sequesterRsrc --keepParent "Mot du jour.app" "$EP/serveur/$ZIP" )
node scripts/signer-archive.js "$EP/serveur/$ZIP" "$EP/cle/cle-maj-privee.pem" "$CLE" || echec "signature de l'archive"
# La signature fausse : une vraie signature… d'un autre contenu.
cp "$EP/serveur/$ZIP" "$EP/serveur/faux/$ZIP"
printf 'autre chose' > "$EP/autre.bin"
node scripts/signer-archive.js "$EP/autre.bin" "$EP/cle/cle-maj-privee.pem" "$CLE" > /dev/null || echec "fausse signature"
cp "$EP/autre.bin.sig" "$EP/serveur/faux/$ZIP.sig"

# 3. Les publications, au format de l'API de GitHub, servies par la machine.
publication() {   # publication <fichier> <préfixe des pièces>
  cat > "$1" <<FIN
{"tag_name":"v$NEUVE_V","draft":false,"prerelease":false,"assets":[
 {"name":"$ZIP","browser_download_url":"http://127.0.0.1:$PORT/$2$ZIP"},
 {"name":"$ZIP.sig","browser_download_url":"http://127.0.0.1:$PORT/$2$ZIP.sig"}]}
FIN
}
publication "$EP/serveur/vraie.json" ""
publication "$EP/serveur/fausse.json" "faux/"
node scripts/serveur-epreuve.js "$EP/serveur" "$PORT" > "$EP/serveur.log" 2>&1 &
SERVEUR=$!
for i in $(seq 1 30); do
  curl -s -m 2 -o /dev/null "http://127.0.0.1:$PORT/vraie.json" && break
  sleep 0.5
done
curl -sS -m 5 -o /dev/null -w "serveur local : HTTP %{http_code}\n" "http://127.0.0.1:$PORT/vraie.json" \
  || echec "le serveur d'épreuve ne répond pas"

preparer_dmg

# A. La signature fausse : rien ne doit bouger.
nettoyer
installer
lancer "$EP/a" "fausse.json"
attendre_fichier "$EP/a/resultat.txt" 60 || echec "A : pas de résultat (l'appli marquée « autorisée » a-t-elle démarré ?)"
echo "A : $(cat "$EP/a/resultat.txt")"
grep -qx "ECHEC la signature de la version $NEUVE_V ne correspond pas" "$EP/a/resultat.txt" \
  || echec "A : la signature fausse n'a pas été refusée pour cette raison-là"
[ "$(version_installee)" = "$VERSION" ] || echec "A : l'appli installée a changé"
[ ! -f "$SUPPORT/maj-attendue.json" ] || echec "A : une annonce de pose traîne"

# B. La bonne : posée, relancée SANS argument, bilan au journal ordinaire.
nettoyer
installer
lancer "$EP/b" "vraie.json"
if ! attendre_ligne "mise à jour : $NEUVE_V posée et relancée" 90; then
  grep -q "ne tourne pas depuis Applications" "$JOURNAL" 2>/dev/null \
    && echec "B : macOS a ISOLÉ l'appli glissée par le Finder (AppTranslocation) — chez elle, elle ne se mettrait jamais à jour"
  echec "B : pas de bilan de la neuve au journal"
fi
[ "$(version_installee)" = "$NEUVE_V" ] || echec "B : l'appli installée n'est pas la neuve"
[ ! -d "$SUPPORT/ancienne.app" ] || echec "B : la sauvegarde de l'ancienne traîne"
[ ! -f "$SUPPORT/maj-attendue.json" ] || echec "B : l'annonce de pose traîne"
pgrep -f "Mot du jour.app/Contents/MacOS/MotDuJour" > /dev/null || echec "B : la neuve ne tourne pas"
echo "B : $NEUVE_V posée, relancée, bilan au journal"
echo "--- journal de B"; cat "$JOURNAL"

# C. Une pose qui rate : l'appli installée verrouillée (elle ne peut pas être
#    mise de côté). L'ancienne doit se relancer, refuser la version pour
#    toujours, et ne plus y revenir.
nettoyer
installer
chflags -R uchg "$INSTALLEE"
lancer "$EP/c" "vraie.json"
attendre_ligne "$NEUVE_V n'a pas pris" 90 || echec "C : l'ancienne n'a pas fait le bilan de la pose ratée"
[ "$(version_installee)" = "$VERSION" ] || echec "C : l'appli installée a changé"
grep -q "\"$NEUVE_V\"" "$SUPPORT/maj-refusees.json" 2>/dev/null || echec "C : la version n'est pas refusée sur le disque"
[ ! -f "$SUPPORT/maj-attendue.json" ] || echec "C : l'annonce de pose traîne"
grep -q "impossible de mettre l'ancienne de côté" "$JOURNAL" || echec "C : le script de pose n'a pas dit pourquoi"
echo "C : pose ratée, l'ancienne est restée, $NEUVE_V refusée pour toujours"
echo "--- journal de C"; cat "$JOURNAL"
chflags -R nouchg "$INSTALLEE"

nettoyer
kill "$SERVEUR" 2>/dev/null
rm -rf "$INSTALLEE"
# Rien de cette épreuve ne doit pouvoir être pris pour une vraie version.
rm -rf "$EP/neuve" "$EP/serveur/$ZIP" "$EP/serveur/faux"
rm -f "$EP/cle/cle-maj-privee.pem"
echo "ÉPREUVE DE LA MISE À JOUR RÉUSSIE (A, B, C)"
