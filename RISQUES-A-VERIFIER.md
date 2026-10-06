# Risques à vérifier

La maison des GO CONDITIONNEL : ce qui reste en suspens et devra être tranché. Entrées les plus récentes en haut.

Format d'une entrée :

```markdown
## AAAA-MM-JJ — Titre court du point en suspens

**Origine :** la tâche et la porte qui ont produit le ⚠️.
**Risque :** ce qui peut mal se passer si on ne tranche jamais.
**À vérifier ou trancher :** la question précise à laquelle il faut répondre.
**Statut :** EN SUSPENS — ou — TRANCHÉ le AAAA-MM-JJ → résultat.
```

---

## 2026-10-06 — La copie du .dmg ne cède pas toujours la place

**Origine :** épreuve D, passage 37520271980 (étiquette v1.0.1), macOS 26 : après `open "/Applications/Mot du jour.app"`, la copie ouverte depuis le .dmg n'a rien écrit en 60 s (ni « rangement », ni aucune ligne de la copie d'Applications). Vert sur les ~12 autres passages de D (4 Mac × 3), où elle cède en moins d'une seconde.
**Risque :** quelqu'un qui ouvre d'abord l'appli depuis le .dmg, puis la range et la rouvre depuis Applications : parfois rien ne se passe — un double-clic de plus à faire. Ne touche pas Kelly (déjà installée). Présent dans la 1.0.0 comme dans la 1.0.1.
**À vérifier ou trancher :** traces ajoutées (la réponse de `open` dans l'épreuve, les exemplaires en route, et au journal de l'appli : « un exemplaire tourne déjà… lui passe la main » / « demande d'un autre exemplaire reçue ») : au prochain rouge, savoir si macOS a lancé la copie d'Applications, si la demande est partie, si elle est arrivée.
**Rejoué le même soir :** rouge encore, mais autrement — le Finder n'a posé AUCUNE marque en glissant depuis le second .dmg monté. Point commun des deux rouges : D montait deux .dmg à la fois (deux copies de l'appli au même identifiant). D simplifié (un seul .dmg, marque posée à la main telle que le Finder la pose ; A, B, C gardent le vrai chemin marqué). Si le rouge « rien reçu » revient malgré tout, les traces diront où ça casse.
**Statut :** EN SUSPENS. Le Mac rouge a été rejoué pour publier la 1.0.1 (la fusée, qui ne touche pas à ce chemin) : un vert rejoué ne tranche RIEN ici — ce rouge rare se lit, il ne se rejoue pas jusqu'au vert.

## 2026-10-06 — L'isolement de macOS chez elle

**Origine :** épreuve de la mise à jour du 06/10 (passage 37469932840) : l'appli glissée par le Finder et marquée « autorisée » tournait isolée (AppTranslocation).
**Risque :** isolée, l'appli ne se met jamais à jour et ne s'inscrit pas au démarrage : l'icône disparaît au premier redémarrage. La parade (Isolement.swift) est éprouvée sur les Mac de GitHub, où « Ouvrir quand même » est imité par la marque 0x40 et le glisser par un `duplicate` du Finder en AppleScript — pas par sa main ni par Réglages Système. La protection « Gestion des apps » de macOS 13+ pourrait aussi refuser que l'appli retire la marque de son propre dossier chez elle.
**À vérifier ou trancher :** après son installation, son journal (`~/Library/Logs/Mot du jour/journal.txt`) : « sortie réussie » ou aucune ligne « isolement » = bon ; « la marque est restée » ou « toujours isolée » = la parade ne suffit pas chez elle.
**Statut :** EN SUSPENS.

## 2026-10-06 — Ce que les Mac de GitHub ne peuvent pas montrer

**Origine :** tour de code du 06/10, partie « non prouvé ».
**Risque :** des comportements qu'aucun Mac d'essai n'atteint :
- un **vrai redémarrage** (l'inscription au démarrage est prouvée « active », pas le retour de l'icône après une ouverture de session) — ni si elle survit à une mise à jour (nouvelle signature ad hoc) ;
- **« Ouvrir quand même » pour de vrai** : l'épreuve marque l'appli « autorisée » par l'attribut de quarantaine (00c1), sans passer par Réglages Système ni par son mot de passe ; la protection « Gestion des apps » de macOS 13+ n'est donc éprouvée que dans cet état-là ;
- **macOS 12** (agent de lancement), **l'encoche** d'un MacBook, **plusieurs écrans**, les **touches mortes** (^, ¨ seuls) ;
- la notification « Éléments d'arrière-plan ajoutés » au premier lancement (annoncée dans la notice).
**À vérifier ou trancher :** son retour à elle, après l'installation et après le premier redémarrage ; puis après la première mise à jour.
**Statut :** EN SUSPENS.

## 2026-10-06 — Son Mac : quelle version de macOS, quelle puce ?

**Origine :** démarrage du projet (P4, supposition déclarée).
**Risque :** une appli fabriquée pour macOS 12+ ne s'ouvre pas sur un Mac plus ancien ; la notice ne montre pas les bons écrans.
**À vérifier ou trancher :** la photo de  → « À propos de ce Mac », demandée à Dova le 06/10. Atténué depuis : essais verts sur macOS 14, 15, 26 et un Mac Intel ; la notice montre l'avertissement de macOS 26 et de macOS 15, et dit le cas de macOS 14.
**Statut :** EN SUSPENS.

## 2026-10-06 — L'icône cachée derrière l'encoche

**Origine :** conception (P3, cas limites).
**Risque :** sur un MacBook à encoche, une barre des menus déjà pleine cache les icônes de trop derrière l'encoche : la sienne pourrait ne jamais se voir.
**À vérifier ou trancher :** parade en place : rouvrir l'appli depuis Applications ouvre le panneau (qu'elle tourne déjà ou non, depuis le tour de code du 06/10) ; la notice le dit, et pointe Réglages Système → Barre des menus (macOS 26). Reste à voir sur SON Mac.
**Statut :** EN SUSPENS.

## 2026-10-06 — Les listes de mots existent en deux exemplaires

**Origine :** conception (Règle 15 : ce qui existe en deux exemplaires se resynchronise, ou le dit).
**Risque :** un mot ajouté aux essais de TokenBar (comme « alien » le 05/10) n'arrive sur le Mac que si on relance `scripts/Generer-Mots.ps1` et qu'on publie une version.
**À vérifier ou trancher :** le dire à Dova à chaque ajout de mots côté TokenBar.
**Statut :** EN SUSPENS (assumé).

## 2026-10-06 — Ce que les Mac de GitHub laissent mesurer

**Origine :** première fabrication (P11, parcours réellement testé).
**Risque :** la photo d'écran entière (`screencapture`) refusée, ou la photo du panneau par la vue elle-même (`cacheDisplay`) vide.
**À vérifier ou trancher :** lire les fichiers du premier passage.
**Statut :** TRANCHÉ le 06/10 → les deux marchent sur macos-14/15/26 (barre des menus et panneau photographiés) ; `osascript` peut cliquer (System Events) et piloter le Finder. Seule limite trouvée : le Mac Intel d'essai n'a pas de carte graphique, les planches (ImageRenderer/Metal) n'y sont pas dessinées.
