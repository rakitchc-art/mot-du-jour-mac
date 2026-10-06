# Mot du jour

Un mot de cinq lettres à trouver chaque jour, en six essais, depuis la **barre des
menus du Mac** : une petite icône en haut à droite, un clic, et la grille tombe
juste en dessous. Le mot du jour de [TokenBar](https://github.com/rakitchc-art), pour
le Mac.

- **Les couleurs :** vert = bonne lettre, bonne place ; jaune = dans le mot, mais
  ailleurs ; gris = pas dans le mot. Un mot inconnu ne compte pas : on retape.
- **Les jours passés :** les flèches ‹ › remontent jusqu'au jour de l'installation ;
  un jour manqué se rattrape (une grille finie, trouvée ou non, ne se rejoue pas).
- **Les statistiques :** série, record, moyenne, répartition des essais.
- **Sans compte, sans internet** pour jouer. L'appli se met à jour toute seule.

## Installation

**La notice illustrée : https://rakitchc-art.github.io/mot-du-jour-mac/**

En bref : télécharger
[Mot-du-jour.dmg](https://github.com/rakitchc-art/mot-du-jour-mac/releases/latest/download/Mot-du-jour.dmg),
l'ouvrir, glisser l'appli dans Applications, l'ouvrir. La première fois, macOS
l'arrête (elle n'est pas notarisée par Apple) : cliquer « Terminé » — jamais
« Placer dans la corbeille » —, puis Réglages Système → Confidentialité et
sécurité → « Ouvrir quand même ». Ensuite, elle se rouvre à chaque démarrage du
Mac et se met à jour toute seule.

## Pour le développement

L'appli est écrite en Swift et se fabrique sur un Mac : les Mac de GitHub s'en
chargent à chaque envoi (`.github/workflows/fabriquer.yml`). Fabriquée une fois,
la même appli est essayée sur macOS 14, 15, 26 et un Mac Intel : une partie jouée
par un robot dans le vrai panneau (minuit compris), la mise à jour posée en vrai,
le démarrage automatique, le vrai clavier. Publier : `scripts/Publier.ps1`, seul
chemin (préversion jugée par l'appli elle-même, puis dernière version).

- `Sources/MotDuJourCore` — les règles, sans interface ;
- `Sources/MotDuJour` — l'appli : l'icône, le panneau, les planches ;
- `scripts/Generer-Mots.ps1` — recopie les listes de mots depuis TokenBar ;
- `scripts/generer-vecteurs.js` — les réponses de référence des tests.

Licences : code sous MIT ; listes de mots sous CC BY-SA 4.0 (Lexique 3.83) et
MPL 2.0 (Grammalecte) — voir [CREDITS.md](CREDITS.md).
