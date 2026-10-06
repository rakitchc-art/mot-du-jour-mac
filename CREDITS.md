# Crédits et licences des éléments repris

Le code de Mot du jour est sous licence MIT (voir `LICENSE`). Les listes de mots,
elles, viennent de deux bases lexicales libres, chacune avec sa licence : elles
vivent dans **deux fichiers séparés**, un par licence.

## Les mots de Lexique 3.83 — `Sources/MotDuJourCore/MotsLexique.swift`

Les mots à trouver (les solutions) et la plupart des mots acceptés en essai sont
**dérivés de Lexique 3.83**, la base lexicale du français de Boris New et
Christophe Pallier (CNRS, Université Aix-Marseille).

- **Source :** http://www.lexique.org (New, B., Pallier, C., Brysbaert, M., Ferrand, L.
  (2004). *Lexique 2 : A new French lexical database.* Behavior Research Methods,
  Instruments, & Computers, 36(3), 516-524.)
- **Licence :** CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/)

**Ce qui a été modifié :** seuls les mots de cinq lettres ont été gardés, sans accent
ni majuscule ; les solutions sont les formes de base courantes à l'oral et à l'écrit,
moins une liste d'exclusions relue à la main (insultes, marques, prénoms, anglicismes
bruts). Ce tri a été fait pour le mot mystère de TokenBar, dont ces listes sont la copie.

**Ce que la licence impose :** citer la source (c'est cette page) et redistribuer toute
dérivation sous la même licence. Le fichier `MotsLexique.swift` est donc sous
**CC BY-SA 4.0**, et non sous la licence MIT du reste.

## Les mots de Grammalecte — `Sources/MotDuJourCore/MotsGrammalecte.swift`

Les formes de cinq lettres que Lexique ne connaît pas (« alien », « emoji »,
« texto »…), acceptées en essai, jamais solutions, viennent du **lexique des formes
fléchies de Grammalecte v7.7** (Olivier R., base Dicollecte).

- **Source :** https://grammalecte.net/dic/lexique-grammalecte-fr-v7.7.zip
- **Licence :** Mozilla Public License 2.0 (http://mozilla.org/MPL/2.0/)

**Ce qui a été modifié :** formes de cinq lettres seulement, sans accent ni majuscule,
sans préfixes ni morceaux de locutions.

**Ce que la licence impose :** le fichier `MotsGrammalecte.swift` reste sous **MPL 2.0**
(la mention est en tête du fichier), et sa forme source est disponible — y compris pour
qui n'a reçu que l'appli — à cette adresse :
https://github.com/rakitchc-art/mot-du-jour-mac/blob/main/Sources/MotDuJourCore/MotsGrammalecte.swift

## Pourquoi deux fichiers

Dans TokenBar, la liste des essais acceptés mêlait les deux sources dans un seul
fichier ; ses crédits prévoyaient, si un dépôt devenait public, de « publier les deux
parts séparément ». Ce dépôt est public : le partage est fait par
`scripts/Generer-Mots.ps1`, contre Lexique 3.83 lui-même (un mot accepté qui est une
forme de Lexique va dans la part Lexique, les autres dans la part Grammalecte).

## Ce qui n'a PAS été repris

Aucun élément de Wordle (New York Times), de SUTOM ni d'aucun autre jeu en ligne :
ni code, ni liste, ni image. Les couleurs vert/jaune/gris sont celles du genre.
