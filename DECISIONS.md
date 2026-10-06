# Décisions structurantes

Ce qui est tranché. Entrées les plus récentes en haut. Voir le CDC (dépôt `protocoles-dev`) pour la règle P12.

Format d'une entrée :

```markdown
## AAAA-MM-JJ — Titre court de la décision

**Décision :** ce qui a été choisi.
**Raison :** pourquoi.
**Alternatives écartées :** lesquelles, et pourquoi elles ont perdu.
**Ce qui invaliderait ce choix :** le signal qui devrait faire rouvrir la question.
```

---

## 2026-10-06 — Le look : B « façon Mac », sans clavier, l'icône grille, la pastille

**Décision :** choisi par Dova sur les planches dessinées par le vrai code sur un Mac de GitHub : le panneau en look **B** (suit le réglage clair / sombre du Mac), **sans clavier à l'écran** (on tape au vrai clavier, comme dans TokenBar), l'icône **4 · grille noir et blanc** (image « modèle » que macOS peint en noir ou en blanc selon la barre), et la **pastille** quand un mot attend (monochrome, comme l'icône). L'icône de l'appli (Applications, .dmg) suivra la grille : planche à venir.
**Raison :** son choix, sur pièces. Mes recommandations étaient « avec clavier » et « tuile verte » ; il a pris la sobriété du style Apple et la fidélité à sa barre.
**Alternatives écartées :** look A (toujours sombre) ; le clavier à l'écran ; la tuile verte, la tuile noir et blanc, les trois cases. Les planches les gardent dessinées (`Apercu.swift`) si la question se rouvre.
**Ce qui invaliderait ce choix :** son retour à elle, sur SON Mac (l'icône qu'elle ne retrouve pas parmi les autres, par exemple).

## 2026-10-06 — Les listes de mots en deux fichiers, un par licence

**Décision :** `MotsLexique.swift` (solutions + acceptés tirés de Lexique 3.83, CC BY-SA 4.0) et `MotsGrammalecte.swift` (les 2 448 acceptés que Lexique ne connaît pas, MPL 2.0, mention en tête). Partage fait par `scripts/Generer-Mots.ps1` contre `Lexique383.tsv` : 5 037 + 2 448 = 7 485, exactement les chiffres notés pour TokenBar le 05/10.
**Raison :** le dépôt est public. Les CREDITS de TokenBar signalaient que sa liste d'acceptés mêle deux licences et prévoyaient ce cas : « publier les deux parts séparément ». Un fichier par licence, c'est l'assemblage que les deux licences autorisent.
**Alternatives écartées :** un seul fichier mêlé (licence ambiguë) ; ne garder que Lexique (« alien », « emoji » redeviendraient refusés — le défaut corrigé le 05/10).
**Ce qui invaliderait ce choix :** un avis juridique contraire, ou une nouvelle source de mots à ajouter (elle aurait alors son propre fichier).

## 2026-10-06 — Un seul dépôt GitHub, public

**Décision :** `rakitchc-art/mot-du-jour-mac`, public : le code ET les versions publiées. (Choix de Dova, sur ma recommandation.)
**Raison :** les fabrications sur les Mac de GitHub sont gratuites et illimitées pour un dépôt public ; en privé, 200 minutes de Mac par mois (les minutes macOS comptent ×10), soit 40 à 60 fabrications, de quoi être bloqué en pleine mise au point. Il n'y a aucun secret dans le code ; elle joue seule, personne n'a de raison de tricher en lisant la liste.
**Alternatives écartées :** code privé + dépôt « versions » public (l'habitude de Dova pour Kitch et Acolyte) — perd sur les minutes.
**Ce qui invaliderait ce choix :** un secret qui devrait vivre dans le code (il irait alors dans les secrets du dépôt, pas dans le code).

## 2026-10-06 — Mise à jour automatique

**Décision :** l'appli se met à jour seule (choix de Dova, contre ma recommandation « tu lui renvoies le fichier »), depuis les publications de ce dépôt public. Chemin prévu : l'API publique de GitHub donne la dernière publication ; l'archive n'est posée que si sa signature Ed25519 est valide pour la clé publique livrée dans l'appli (clé privée : seulement dans les secrets du dépôt). Une version refusée ne se retente jamais (mémoire sur le disque, leçon de TokenBar). Le cœur de la décision est écrit et testé (`MiseAJourCoeur.swift`) ; le geste (télécharger, poser, relancer) reste à écrire et à éprouver en vrai.
**Raison :** corriger un mot refusé à tort sans qu'elle ait rien à faire.
**Alternatives écartées :** le framework Sparkle (plus lourd à emballer, opaque à éprouver) — à reconsidérer si le geste maison bute sur une protection de macOS.
**Ce qui invaliderait ce choix :** macOS qui refuse qu'une appli non signée par Apple se remplace elle-même.

## 2026-10-06 — Elle joue seule, avec son propre mot

**Décision :** les listes de TokenBar sont DANS l'appli ; le mot du jour se calcule sur le Mac : solutions triées par HMAC-SHA256 (clé publique `mot-du-jour-mac`), jour 0 = 2026-09-01, jour civil du Mac en calendrier grégorien. Le même mot pour tous ceux qui ont l'appli Mac. La solution est COPIÉE dans la grille au premier essai. Les couleurs sont celles de `couleursDe` du serveur TokenBar, prouvées contre elle (`vecteurs.json`, produit par la fonction extraite du serveur). Jours passés : depuis son installation, rattrapables. Stats : les siennes, aux règles de `statsMotDe`. Nom : « Mot du jour ».
**Raison :** décisions de Dova le 06/10 (trois questions groupées). Marche sans internet, ne touche pas au serveur des échecs (verrouillé à deux joueurs : « on ne peut jouer qu'entre nous »).
**Alternatives écartées :** le même mot que Dova et Nisse (troisième place sur leur serveur) ; un duel avec quelqu'un à elle (second serveur, appli réseau) — plus lourds, et touchent à ce qui tourne en production.
**Ce qui invaliderait ce choix :** l'envie de jouer CONTRE quelqu'un.

## 2026-10-06 — Une appli Swift fabriquée sur les Mac de GitHub, sans compte Apple

**Décision :** Swift (paquet SPM, sans projet Xcode), AppKit pour l'icône de la barre des menus et le panneau (NSStatusItem + NSPopover), SwiftUI pour le dessin. Binaire universel (puce Apple + Intel), macOS 12 minimum. Signature ad hoc ; un .dmg pour l'installation, un .zip pour les mises à jour. Fabrication et épreuves sur `macos-15` (GitHub Actions).
**Raison :** une appli Mac ne se fabrique que sur un Mac, et Dova n'en a pas. Sans compte Apple Developer (99 €/an), macOS bloque la première ouverture : elle fera « Ouvrir quand même » une fois (Réglages Système → Confidentialité et sécurité), notice à lui écrire.
**Alternatives écartées :** SwiftBar/xbar (un logiciel de plus à installer, pas de grille) ; Electron/Tauri (100 Mo pour un jeu de mots, ou fabrication aussi sur Mac) ; une page web (ni icône dans la barre des menus, ni hors ligne).
**Ce qui invaliderait ce choix :** l'achat d'un compte Apple Developer (il suffirait alors d'ajouter la signature et la notarisation à `construire-app.sh`).
