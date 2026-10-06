#!/bin/bash
# ============================================================================
#  deballer.sh — sur un Mac d'essai : l'appli fabriquée UNE fois (pièce jointe
#  « appli » du job de fabrication) est déballée dans sortie/, avec ditto, qui
#  garde les droits et la signature (une pièce jointe GitHub ne garde pas le
#  droit d'exécuter). C'est donc la MÊME appli qui est essayée partout, et
#  celle-là qui sera publiée.
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIVE=$(ls sortie/Mot-du-jour-*.zip | grep -v '\.sig$' | head -1)
rm -rf "sortie/Mot du jour.app"
ditto -x -k "$ARCHIVE" sortie/
APP="sortie/Mot du jour.app"
codesign --verify --deep --strict "$APP"
echo "déballée : $("$APP/Contents/MacOS/MotDuJour" --version) — tranches : $(lipo -archs "$APP/Contents/MacOS/MotDuJour") — ce Mac : $(uname -m), macOS $(sw_vers -productVersion)"
