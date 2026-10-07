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

## 2026-10-07 — « Dire à Dova quand j'ai joué » (1.0.4)

**Décision :** une fois par jour joué, l'appli envoie `{"jour", "version"}` à un registre sur le VPS (`serveur-activite/serveur.mjs`, `/root/projets/mot-du-jour-activite`, derrière `https://retroseance.fr/mot-du-jour/` comme les licences Kitch). Rien d'autre : ni le mot, ni les essais, ni de nom. Le registre ne se lit PAS par le web : Claude le lit par SSH quand Dova demande. Ligne de menu « Dire à Dova quand j'ai joué », cochée, que Kelly peut décocher (choix gardé) ; la notice le dit.
**Raison :** Dova veut « juste pouvoir savoir si elle se sert de l'appli », Kelly est d'accord ; pas de notification (« quand je demande tu me dis »), le strict minimum envoyé (« juste elle a joué »).
**Comment :** les jours à signaler se TIRENT du carnet (jours des essais, à l'heure du Mac, 7 derniers jours, pas encore acceptés) — un jour joué hors connexion part plus tard ; un jour refusé (4xx) est abandonné pour ne pas bloquer les suivants ; échec passager : nouvel essai 10 min plus tard. L'adresse étant publique, le registre ne note un jour qu'une fois, dans une fenêtre de dates, avec un plafond par jour et une taille plafonnée — n'importe qui pourrait y écrire un faux « a joué » : c'est un indice amical, pas une preuve.
**Épreuves :** `serveur-activite/eprouver.mjs` (19 contrôles, et il échoue sur une copie sabotée) ; sur les 4 Mac, l'épreuve du vrai clavier fait arriver le jour joué au VRAI serveur lancé en local — l'appli n'accepte une adresse locale qu'en épreuve, et les copies des autres épreuves ont une adresse inutilisable : aucune épreuve n'écrit dans le registre de Dova.
**Alternatives écartées :** une notification sur son téléphone (il n'en veut pas) ; un service gratuit en ligne (adresse publique ET lecture publique) ; envoyer le résultat (il a choisi « juste elle a joué »).
**Ce qui invaliderait ce choix :** Kelly qui ne veut plus (elle décoche) ; un registre rempli de faux jours.

## 2026-10-06 — Pas de catégorie « jeux » dans Info.plist

**Décision :** plus de `LSApplicationCategoryType` (c'était `public.app-category.word-games`), à partir de la 1.0.3 (étiquettes v1.0.1 et v1.0.2 posées, jamais publiées, jamais réutilisées : v1.0.1 rouge sur l'épreuve D ; v1.0.2 refusée par le contrôle de l'appli, l'API de GitHub ayant répondu 403 — limite des questions sans compte épuisée par les Mac de GitHub ; le contrôle passe désormais avec le jeton du job).
**Raison :** macOS 26 traite toute appli d'une catégorie « jeux » comme un jeu et affiche, tant qu'elle tourne, son bouton « Mode Jeu » (une fusée) dans la barre des menus. Notre appli tournant en permanence, la fusée y restait — vue par Kelly le soir de la 1.0.0. Elle était déjà sur la photo macOS 26 des essais (`ecran-panneau-ouvert.png`), absente de la photo prise avant le lancement (`notice/1-dmg-ouvert.png`) : personne ne l'avait remarquée.
**Alternatives écartées :** une autre catégorie (elle ne sert qu'au classement de l'App Store, où l'appli n'est pas) ; lui faire retirer la fusée à la main (⌘-glisser, pas sûr que macOS le permette pour ce bouton).
**Ce qui invaliderait ce choix :** la fusée encore là sur la photo macOS 26 des essais (absente dès le passage 37519627274), ou chez elle après la mise à jour.

## 2026-10-06 — L'appli isolée par macOS se relance depuis Applications

**Décision :** si macOS lance l'appli depuis une copie isolée (`…/AppTranslocation/…`) alors que son vrai emplacement est dans Applications, elle retire la marque « téléchargée » de ce vrai emplacement, se relance depuis là et quitte (Sources/MotDuJour/Isolement.swift). Le vrai emplacement se demande à Security par `SecTranslocateCreateOriginalPathForURL` (non publiée, chargée par `dlsym` : absente un jour = rien ne se fait, le rappel « Range-moi » reste). Une seule tentative : la relance porte `--sortie-isolement` et n'insiste pas. Et (relecture ciblée du même jour) **une copie qui tourne hors d'Applications cède toujours la place** à celle d'Applications, au lancement comme quand on la rappelle : ouverte d'abord depuis le .dmg puis rangée, c'est sinon la copie du .dmg qui se rouvrait (« Range-moi… » sans fin, jamais inscrite au démarrage). Le rappel « Range-moi » se juge sur le VRAI emplacement. Épreuve D : ce chemin, sans argument, sur les 4 Mac.
**Raison :** mesuré le 06/10 sur les Mac de GitHub (passage 37469932840) : l'appli glissée par le Finder depuis un .dmg marqué par Safari, puis marquée « autorisée » (00c3), tournait quand même isolée — sans mise à jour possible ni démarrage automatique. Que chez elle « Ouvrir quand même » fasse pareil ou non, la parade couvre les deux cas.
**Alternatives écartées :** compter sur le Finder et « Ouvrir quand même » (non prouvé, et mesuré faux dans l'épreuve) ; une notice qui lui fait taper `xattr` dans le Terminal (pas pour quelqu'un de non technique) ; un compte Apple Developer et la notarisation (99 €/an, écarté au départ).
**Ce qui invaliderait ce choix :** un journal de son Mac qui dit « isolement : la marque de téléchargement est restée » ou « toujours isolée après la relance » ; ou la fonction de Security retirée par Apple.

## 2026-10-06 — Le tour de code : ce qui a changé de règle

**Décision :** après le tour de code indépendant (22 points, aucun bloquant dans le code qui avait tourné) :
- **Mise à jour** : la sauvegarde de l'ancienne version vit dans Application Support (plus dans les Caches, que macOS peut vider) ; le script de pose SURVEILLE la neuve deux minutes — sans bilan, l'ancienne revient et refuse la version pour toujours ; on ne pose jamais avec une alerte ouverte ; ditto et codesign hors du fil de l'interface.
- **Publication en deux temps** : la version part en « préversion » (invisible des applis installées), l'appli elle-même la juge en ligne, puis seulement elle devient « dernière version » — sinon elle est retirée.
- **Démarrage automatique** : inscrit à CHAQUE lancement depuis Applications s'il ne l'est pas (un échec se retente et s'écrit au journal) ; jamais hors d'Applications ; coupé dans le menu = jamais réinscrit d'office. Sous macOS 12, l'agent passe `--au-demarrage`.
- **Le panneau s'ouvre quand ELLE lance l'appli** (pas seulement la première fois) — jamais à l'ouverture de session, jamais à la relance d'une mise à jour. Un second exemplaire demande au premier d'ouvrir son panneau et s'en va.
- **Le clavier** : seules les frappes destinées au panneau sont prises (une alerte garde les siennes).
- **Comme TokenBar** : chaque ouverture revient au jour courant, ligne vide ; les stats affichées n'acceptent pas de lettres.
- **Carnet** : jamais réécrit s'il est d'une version plus récente, ou illisible et impossible à mettre de côté.
- **Hors d'Applications** : un rappel « Range-moi dans Applications pour que je reste » à chaque ouverture.
**Raison :** chacun de ces points pouvait laisser son amie avec une appli qui ne revient pas, ne se met plus à jour, ou perd une partie — sans qu'elle puisse comprendre pourquoi.
**Alternatives écartées :** livrer d'abord et corriger ensuite (personne ne peut réparer chez elle) ; une fenêtre « Déplacer dans Applications » qui se déplace toute seule (copie isolée de macOS : chemin d'origine inconnu sans API privée — l'API privée a finalement servi, voir l'entrée « L'appli isolée par macOS »).
**Ce qui invaliderait ce choix :** un retour réel de son Mac qui contredit l'une de ces suppositions.

## 2026-10-06 — Écart assumé avec TokenBar : « rattrapé » se juge au fuseau du Mac

**Décision :** un jour compte « rattrapé » dans les stats si son premier essai a été joué un jour civil plus tard, **dans le fuseau du Mac au moment du calcul** (TokenBar juge au fuseau fixe Europe/Paris de son serveur).
**Raison :** il n'y a pas de serveur ; elle joue seule, dans son fuseau. Le seul effet d'un voyage : un compteur « dont N rattrapés » qui peut varier d'une unité.
**Alternatives écartées :** garder le fuseau de chaque essai (un champ de plus dans le carnet pour une statistique secondaire).
**Ce qui invaliderait ce choix :** un jeu à deux, où le jour doit être le même pour les deux joueurs.

## 2026-10-06 — Le look : B « façon Mac », sans clavier, l'icône grille, la pastille

**Décision :** choisi par Dova sur les planches dessinées par le vrai code sur un Mac de GitHub : le panneau en look **B** (suit le réglage clair / sombre du Mac), **sans clavier à l'écran** (on tape au vrai clavier, comme dans TokenBar), l'icône **4 · grille noir et blanc** (image « modèle » que macOS peint en noir ou en blanc selon la barre), et la **pastille** quand un mot attend (monochrome, comme l'icône). L'icône de l'appli (Applications, .dmg) : devant trois versions en couleurs, « **en noir et blanc très soft** » — planche 4b de trois nuances, il a pris **2 · gris perle** (`Icone.appliRetenue`).
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

**Décision :** l'appli se met à jour seule (choix de Dova, contre ma recommandation « tu lui renvoies le fichier »), depuis les publications de ce dépôt public. L'API publique de GitHub donne la dernière publication ; l'archive n'est posée que si sa signature Ed25519 est valide pour la clé publique livrée dans l'appli (clé privée : seulement dans les secrets du dépôt, et une copie hors du dépôt sur le PC de Dova). Une version refusée ne se retente jamais (mémoire sur le disque, leçon de TokenBar). Écrit (`MiseAJourCoeur.swift`, `MiseAJour.swift`) et éprouvé en vrai sur quatre Mac par `scripts/epreuve-maj.sh` : signature fausse refusée, bonne version posée et relancée, pose ratée sans boucle.
**Raison :** corriger un mot refusé à tort sans qu'elle ait rien à faire.
**Alternatives écartées :** le framework Sparkle (plus lourd à emballer, opaque à éprouver) — à reconsidérer si le geste maison bute sur une protection de macOS.
**Ce qui invaliderait ce choix :** macOS qui refuse qu'une appli non signée par Apple se remplace elle-même.

## 2026-10-06 — Elle joue seule, avec son propre mot

**Décision :** les listes de TokenBar sont DANS l'appli ; le mot du jour se calcule sur le Mac : solutions triées par HMAC-SHA256 (clé publique `mot-du-jour-mac`), jour 0 = 2026-09-01, jour civil du Mac en calendrier grégorien. Le même mot pour tous ceux qui ont l'appli Mac. La solution est COPIÉE dans la grille au premier essai. Les couleurs sont celles de `couleursDe` du serveur TokenBar, prouvées contre elle (`vecteurs.json`, produit par la fonction extraite du serveur). Jours passés : depuis son installation, rattrapables. Stats : les siennes, aux règles de `statsMotDe`. Nom : « Mot du jour ».
**Raison :** décisions de Dova le 06/10 (trois questions groupées). Marche sans internet, ne touche pas au serveur des échecs (verrouillé à deux joueurs : « on ne peut jouer qu'entre nous »).
**Alternatives écartées :** le même mot que Dova et Nisse (troisième place sur leur serveur) ; un duel avec quelqu'un à elle (second serveur, appli réseau) — plus lourds, et touchent à ce qui tourne en production.
**Ce qui invaliderait ce choix :** l'envie de jouer CONTRE quelqu'un.

## 2026-10-06 — Une appli Swift fabriquée sur les Mac de GitHub, sans compte Apple

**Décision :** Swift (paquet SPM, sans projet Xcode), AppKit pour l'icône de la barre des menus et le panneau (NSStatusItem + NSPopover), SwiftUI pour le dessin. Binaire universel (puce Apple + Intel), macOS 12 minimum. Signature ad hoc ; un .dmg pour l'installation (sans numéro dans le nom : lien stable), un .zip pour les mises à jour. Fabrication sur `macos-15`, puis la MÊME appli essayée sur `macos-14`, `macos-15`, `macos-26` et `macos-15-intel` (GitHub Actions).
**Raison :** une appli Mac ne se fabrique que sur un Mac, et Dova n'en a pas. Sans compte Apple Developer (99 €/an), macOS bloque la première ouverture : elle fera « Ouvrir quand même » une fois (Réglages Système → Confidentialité et sécurité), notice à lui écrire.
**Alternatives écartées :** SwiftBar/xbar (un logiciel de plus à installer, pas de grille) ; Electron/Tauri (100 Mo pour un jeu de mots, ou fabrication aussi sur Mac) ; une page web (ni icône dans la barre des menus, ni hors ligne).
**Ce qui invaliderait ce choix :** l'achat d'un compte Apple Developer (il suffirait alors d'ajouter la signature et la notarisation à `construire-app.sh`).
