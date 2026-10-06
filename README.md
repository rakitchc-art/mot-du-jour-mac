# Mot du jour

Un mot de cinq lettres à trouver chaque jour, en six essais, depuis la **barre des
menus du Mac** : une petite icône en haut à droite, un clic, et la grille tombe
juste en dessous. Le mot du jour de [TokenBar](https://github.com/rakitchc-art), pour
le Mac.

- **Les couleurs :** vert = bonne lettre, bonne place ; jaune = dans le mot, mais
  ailleurs ; gris = pas dans le mot. Un mot inconnu ne compte pas : on retape.
- **Les jours passés :** les flèches ‹ › remontent jusqu'au jour de l'installation ;
  un jour raté se rattrape.
- **Les statistiques :** série, record, moyenne, répartition des essais.
- **Sans compte, sans internet** pour jouer. L'appli se met à jour toute seule.

## Installation

*La première version est en préparation.* La marche à suivre (ouvrir le `.dmg`,
glisser l'appli dans Applications, et la première ouverture à autoriser dans
Réglages Système) sera écrite ici avec elle.

## Pour le développement

L'appli est écrite en Swift et se fabrique sur un Mac : les Mac de GitHub s'en
chargent à chaque envoi (`.github/workflows/fabriquer.yml`), avec les tests du jeu,
les planches des looks et une partie jouée par un robot dans le vrai panneau.

- `Sources/MotDuJourCore` — les règles, sans interface ;
- `Sources/MotDuJour` — l'appli : l'icône, le panneau, les planches ;
- `scripts/Generer-Mots.ps1` — recopie les listes de mots depuis TokenBar ;
- `scripts/generer-vecteurs.js` — les réponses de référence des tests.

Licences : code sous MIT ; listes de mots sous CC BY-SA 4.0 (Lexique 3.83) et
MPL 2.0 (Grammalecte) — voir [CREDITS.md](CREDITS.md).
