#!/bin/bash
# ============================================================================
#  epreuve-maj.sh — la mise à jour automatique, éprouvée EN VRAI sur un Mac
#  (ceux de GitHub) : l'appli installée dans /Applications comme chez elle,
#  une « version suivante » servie par la machine elle-même, et l'appli qui
#  la trouve, la vérifie, la pose et se relance. Deux épreuves :
#    A. une signature FAUSSE : rien ne doit bouger ;
#    B. la bonne : la neuve doit tourner, et la sauvegarde de l'ancienne
#       doit être effacée.
#  La clé est une clé d'épreuve, jetable — jamais celle des vraies versions.
#  Le code de l'appli est le vrai ; seuls l'adresse et la clé changent, et
#  l'autorisation des adresses locales est ajoutée aux COPIES d'épreuve
#  (jamais à l'appli livrée).
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
rm -rf "$EP"
mkdir -p "$EP/serveur/faux" "$EP/neuve"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")

echec() {
  echo "ÉPREUVE RATÉE : $1"
  for f in "$EP/a/resultat-maj.txt" "$EP/a/journal.txt" "$EP/a.sortie.txt" "$EP/b/resultat-maj.txt" \
           "$EP/b/journal.txt" "$EP/b.sortie.txt" "$EP/serveur.log"; do
    [ -f "$f" ] && { echo "--- $f"; cat "$f"; }
  done
  [ -n "$SERVEUR" ] && kill "$SERVEUR" 2>/dev/null
  exit 1
}
attendre() {   # attendre <fichier> <secondes>
  local n=0
  while [ ! -f "$1" ]; do
    sleep 0.5
    n=$((n + 1))
    if [ "$n" -ge $(( $2 * 2 )) ]; then return 1; fi
  done
  return 0
}
version_installee() { /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INSTALLEE/Contents/Info.plist"; }
autoriser_local() {   # sur une copie d'épreuve seulement : les adresses locales en http
  /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" \
                          -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" "$1/Contents/Info.plist"
  codesign --force --deep --sign - "$1"
}

# 1. Une clé d'épreuve, jetable.
node scripts/creer-cle.js "$EP/cle" > /dev/null || echec "clé d'épreuve"
CLE=$(tr -d '\n' < "$EP/cle/cle-maj-publique.txt")

# 2. La « version suivante » : la même appli, numéro $NEUVE_V, re-signée ad hoc.
cp -R "$APP" "$EP/neuve/"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEUVE_V" "$EP/neuve/Mot du jour.app/Contents/Info.plist"
autoriser_local "$EP/neuve/Mot du jour.app" || echec "signature de code de la neuve"
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
# Attendre qu'il RÉPONDE, pas un délai deviné. (2e passage, 06/10 : le serveur
# de Python ne répondait pas même au terminal — voir serveur-epreuve.js.)
for i in $(seq 1 30); do
  curl -s -m 2 -o /dev/null "http://127.0.0.1:$PORT/vraie.json" && break
  sleep 0.5
done
if curl -sS -m 5 -o /dev/null -w "serveur local : HTTP %{http_code}\n" "http://127.0.0.1:$PORT/vraie.json"; then :; else
  echo "serveur local : ne répond pas au terminal"; lsof -nP -iTCP:"$PORT" || true; echec "le serveur d'épreuve ne répond pas"
fi

# 4. L'appli installée comme chez elle.
rm -rf "$INSTALLEE"
cp -R "$APP" "$INSTALLEE" || echec "installation dans /Applications"
autoriser_local "$INSTALLEE" || echec "copie d'épreuve"
echo "installée : $(version_installee)"

# L'appli installée, lancée comme un double-clic (`open`, par LaunchServices) :
# c'est ainsi qu'elle tournera chez elle. (Le 1er passage du 06/10 avait
# accusé l'appli ; la mesure a montré que c'était le serveur de Python.)
lancer() {   # lancer <dossier> <publication>
  open -n "$INSTALLEE" --args --epreuve-maj "$1" "http://127.0.0.1:$PORT/$2" "$CLE"
}

# A. La signature fausse : rien ne doit bouger.
lancer "$EP/a" "fausse.json"
attendre "$EP/a/resultat-maj.txt" 60 || echec "A : pas de résultat"
echo "A : $(cat "$EP/a/resultat-maj.txt")"
grep -q "^ECHEC .*signature" "$EP/a/resultat-maj.txt" || echec "A : la signature fausse n'a pas été refusée"
[ "$(version_installee)" = "$VERSION" ] || echec "A : l'appli installée a changé"
sleep 1

# B. La bonne : posée, relancée, bilan écrit par la NEUVE.
lancer "$EP/b" "vraie.json"
attendre "$EP/b/resultat-maj.txt" 90 || echec "B : pas de bilan"
echo "B : $(cat "$EP/b/resultat-maj.txt")"
grep -q "^REUSSI $NEUVE_V" "$EP/b/resultat-maj.txt" || echec "B : la pose n'a pas réussi"
[ "$(version_installee)" = "$NEUVE_V" ] || echec "B : l'appli installée n'est pas la neuve"
grep -q "sauvegarde effacée" "$EP/b/resultat-maj.txt" || echec "B : la sauvegarde de l'ancienne traîne"
echo "--- journal de B"
cat "$EP/b/journal.txt"

kill "$SERVEUR" 2>/dev/null
rm -rf "$INSTALLEE"
echo "ÉPREUVE DE LA MISE À JOUR RÉUSSIE"
