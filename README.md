# Nurikabe pour Playdate

Casse-tête Nurikabe avec trois entrées dans le menu d'accueil :

- **Niveaux** : 4 difficultés de 12 grilles chacune — Facile 7x7, Moyen 8x8, Difficile 10x10, Expert 12x12.
  Dans chaque difficulté, les grilles vont de la plus simple à la plus dure.
- **Mosaïques** : 6 images secrètes. Chaque image est découpée en pièces ; chaque pièce est un Nurikabe 8x8.
  Une fois résolues, les cases noires des pièces assemblées dessinent l'image. Quand l'image est finie,
  la manivelle bascule entre ton dessin et le modèle.
- **Tutoriel** : les règles illustrées, les commandes, des astuces, puis une grille d'entraînement.

Toutes les grilles ont une solution unique (vérifiée par un solveur).

## Règles
- Chaque chiffre appartient à une **île** blanche contenant exactement ce nombre de cases.
- Chaque île contient **un seul** chiffre ; deux îles ne se touchent jamais par un côté.
- Toutes les cases noires (la **mer**) sont reliées entre elles.
- La mer ne contient aucun **carré 2x2** noir.

## Commandes
| Bouton | Action |
|---|---|
| ✛ Croix | Déplacer le curseur (il fait le tour de la grille) |
| Ⓐ | Noircir / effacer une case |
| Ⓑ | Poser / retirer un point (case blanche) |
| Ⓐ ou Ⓑ maintenu + ✛ | Peindre plusieurs cases d'un coup |
| Manivelle arrière / avant | Annuler / refaire |
| Menu système | Retour · Recommencer · Indice |

Aides visuelles : chiffre sur fond grisé = île impossible ; rond blanc à un coin = carré 2x2 noir ;
croix = groupe de points enfermé sans chiffre.

La progression (grilles en cours, records, mosaïques) est sauvegardée automatiquement.

## Lancer le jeu
1. Installer le SDK Playdate : https://play.date/dev/
2. Double-cliquer sur `lancer.bat` (compile `source/` en `Nurikabe.pdx` puis ouvre le simulateur).

Si le SDK est dans `C:\Program Files`, le simulateur ne peut pas sauvegarder : `lancer.bat` l'indique
et donne la commande à lancer une fois dans un terminal administrateur.

## Structure
- `source/main.lua` — point d'entrée, boucle, routage des boutons
- `source/common.lua` — polices, sons, sauvegarde, gestion des écrans
- `source/home.lua`, `levels.lua`, `mosaic.lua`, `tutorial.lua`, `game.lua` — les écrans
- `source/board.lua` — logique d'une grille (règles, erreurs, annuler, indices)
- `source/puzzles.lua`, `source/mosaics.lua` — les grilles (générées)
- `outils/` — générateur Python (nécessite le solveur `clingo`) :
  `python3 nurigen3.py levels <graine> <sortie> <0-3>` ou `python3 nurigen3.py mosaic <graine> <sortie> <image>`.
  Les images des mosaïques sont décrites dans `mosaic_images.py`.
