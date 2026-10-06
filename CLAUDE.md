# Mot du jour (Mac) — ce qu'il faut savoir avant de toucher

- Le mot du jour de TokenBar pour le Mac d'une amie de Dova : une appli de la
  barre des menus, elle joue SEULE (décisions du 06/10/2026 dans `DECISIONS.md`).
- **Dépôt PUBLIC** (`rakitchc-art/mot-du-jour-mac`) : rien de secret dans le code,
  jamais. Avant chaque envoi : `powershell -File scripts\Verifier-Publication.ps1`
  → « 0 trouvée ». Il lit les valeurs à chercher sur la machine (utilisateur,
  machine, serveurs de ~/.ssh/config) : ne JAMAIS les écrire dans un fichier
  du dépôt, même pour les chercher.
- **Ne jamais toucher au dossier `token-bar`** : on y LIT les listes de mots
  (`scripts/Generer-Mots.ps1`) et la fonction des couleurs
  (`scripts/generer-vecteurs.js`), on n'y écrit rien. D'autres conversations y
  travaillent.
- On ne fabrique PAS sur ce PC (Windows) : chaque envoi sur `main` fabrique et
  éprouve l'appli sur un Mac de GitHub ; les planches, photos et journaux sont
  dans la pièce jointe du passage (`gh run download`).
- La liste des SOLUTIONS ne change jamais à la légère (elle fixe le mot de chaque
  jour) : garde dans `Generer-Mots.ps1`, contrôle dans `ReglesTests`.

# Protocoles de développement

Référence complète : dépôt `protocoles-dev` (CDC-protocoles-developpement.md).
Fichiers compagnons de ce projet : `DECISIONS.md` (tranché), `RISQUES-A-VERIFIER.md` (en suspens), `REX.md` (leçons des incidents).

## Checklist — à appliquer à chaque tâche

```
AVANT TOUTE MODIFICATION, VÉRIFIER :
1. Je sais exactement ce qui est demandé et ce qui est hors périmètre
2. Je sais à quoi on reconnaîtra que c'est terminé
3. J'ai listé les cas limites et leur comportement est défini
4. J'ai signalé ce que je suppose sans l'avoir vérifié
5. J'ai identifié ce que ma modification peut casser ailleurs
6. J'ai cherché la solution la plus simple qui répond au besoin
7. Rien de destructif sans sauvegarde préalable
8. Je vérifie que l'existant fonctionne toujours après modification
9. Je consigne toute décision structurante dans DECISIONS.md
10. Aucune valeur du poste de dev en dur (chemin, utilisateur, IP,
    machine) — déduite de l'environnement, ou échec explicite ;
    le code de test compte, il part dans le binaire livré

AVANT DE DIRE « TERMINÉ » :
11. Parcours principal réellement testé de bout en bout ; toute
    fenêtre nouvelle ou modifiée capturée en image et regardée
12. grep du nom d'utilisateur / de l'IP sur les sources : zéro résultat

SI UNE DE CES CONDITIONS N'EST PAS REMPLIE :
→ NE PAS CODER. POSER LA QUESTION.

FACE À DEUX OPTIONS AUX CONSÉQUENCES IMPORTANTES :
→ NE PAS TRANCHER SEUL. PRÉSENTER LES OPTIONS.

SI LE PROJET INSTALLE, MET À JOUR OU TOUCHE LA MACHINE D'AUTRUI :
→ Les 12 serments du technicien (CDC §2) : chaque bug vécu devient
  un verrou, chaque secret a le sien, chaque action sa sauvegarde
  datée, chaque échec son chemin de retour — joué en réel une fois.

TOUT SCRIPT JETABLE (analyse, vérification, mesure) — Règle 8 :
→ L'écrire dans `scripts/`, puis le lancer depuis ce fichier. Jamais
  de code à la volée (`python -`, `python -c`, heredoc) : non
  rejouable, et impose une validation que l'utilisateur ne peut pas
  juger. Seule exception : une ligne unique, sans logique ni boucle.

CONSULTER OU MODIFIER UN FICHIER — Règle 9 :
→ Outils dédiés : lecture avec plage de lignes, recherche par motif,
  édition ciblée. Jamais `cat`, `head`, `tail`, `sed`, `awk`, `grep`,
  `type`, `Get-Content`, `Set-Content` : demande de validation
  inutile, et un motif accentué peut rendre un vide SANS erreur.

RELIRE, RÉPARER, RÉÉCRIRE — Règles 10 à 15 :
→ L'outil qui produit les preuves se relit AVANT ce qu'il mesure ;
  ses détecteurs s'éprouvent sur des cas fabriqués, et une capture
  ne montre qu'un état — provoquer les autres ou les déclarer non vus.
→ Un contrôle se prouve par son échec, et le levier d'échec se
  vérifie : un levier qui n'échoue pas rend l'épreuve muette.
→ Réécrire une couche, c'est hériter de ses défauts : rejouer sur la
  nouvelle la liste des correctifs de l'ancienne.
→ Un correctif est une modification : que casse-t-il ailleurs ?
→ Vérifier l'EFFET d'une opération, jamais son code de retour.
→ Ce qui existe en deux exemplaires se resynchronise, ou le dit.
→ Un contrôle qu'on vient de modifier se rejoue dans les DEUX sens :
  nominal au vert, levier au rouge. Les contrôles font partie de
  « ailleurs » — un contrôle désarmé continue de dire oui.
→ Une action de l'utilisateur produit un signe visible même quand
  elle ne change rien, sinon elle passe pour cassée.
→ Un outil du quotidien s'installe : un geste écrit, qui vérifie ses
  effets. Un dossier de compilation n'est pas une adresse.
```

## Compte rendu

Le silence vaut conforme : ne rapporter que les ⚠️ et les ❌. Tout GO CONDITIONNEL est consigné dans `RISQUES-A-VERIFIER.md`. Tout bug passé à travers les protocoles est consigné dans `REX.md` et doit conclure : CDC modifié, ou CDC suffisant mais mal appliqué.
