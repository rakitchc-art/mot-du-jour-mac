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

## 2026-10-06 — Son Mac : quelle version de macOS, quelle puce ?

**Origine :** démarrage du projet (P4, supposition déclarée).
**Risque :** une appli fabriquée pour macOS 12+ ne s'ouvre pas sur un Mac plus ancien ; la notice « Ouvrir quand même » ne montre pas les bons écrans.
**À vérifier ou trancher :** la photo de  → « À propos de ce Mac », demandée à Dova le 06/10.
**Statut :** EN SUSPENS.

## 2026-10-06 — L'icône cachée derrière l'encoche

**Origine :** conception (P3, cas limites).
**Risque :** sur un MacBook à encoche, une barre des menus déjà pleine (« plein de petites icônes ») cache les icônes de trop derrière l'encoche : la sienne pourrait ne jamais se voir.
**À vérifier ou trancher :** parade en place : un double-clic sur l'appli ouvre le panneau, et le premier lancement l'ouvre tout seul. À voir sur SON Mac ; la notice dira comment ranger les icônes (⌘ + glisser).
**Statut :** EN SUSPENS.

## 2026-10-06 — Les listes de mots existent en deux exemplaires

**Origine :** conception (Règle 15 : ce qui existe en deux exemplaires se resynchronise, ou le dit).
**Risque :** un mot ajouté aux essais de TokenBar (comme « alien » le 05/10) n'arrive sur le Mac que si on relance `scripts/Generer-Mots.ps1` et qu'on publie une version.
**À vérifier ou trancher :** le dire à Dova à chaque ajout de mots côté TokenBar.
**Statut :** EN SUSPENS (assumé).

## 2026-10-06 — Ce que les Mac de GitHub laissent mesurer

**Origine :** première fabrication (P11, parcours réellement testé).
**Risque :** la photo d'écran entière (`screencapture`) peut être refusée par macOS sur la machine de GitHub (autorisation d'enregistrement de l'écran) ; la photo du panneau par la vue elle-même (`cacheDisplay`) peut rendre vide un contenu SwiftUI. Une épreuve qui ne photographie rien ne prouve pas l'affichage.
**À vérifier ou trancher :** lire les fichiers du premier passage.
**Statut :** EN SUSPENS.
