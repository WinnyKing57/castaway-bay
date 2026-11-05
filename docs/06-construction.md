# 06 — Construction : mode, grille et éléments

Système piloté par le nœud **`Construction`** (`systems/construction.gd`).

## 1. Activation

- **B** : bascule le mode construction.
- Panneau HUD : sélection d'élément, taille d'empreinte (`grid_size`).

## 2. Grille et pose

- Grille de 1 m (cases).
- Clic gauche : pose (via `place_free`).
- **R** : rotation (0 / 90° / 180° / 270°).
- Molette : changement d'élément.
- Clic droit : **démolition** avec remboursement 75 % des matériaux.

## 3. Règles avancées

1. **Ancrage** : première pièce au sol (niveau 0) ancrée sur la terre ferme.
2. **Étages** : **PgUp / PgDn** changent de niveau ; un niveau ≥ 1 exige une
   fondation/support en dessous.
3. **Alignement fantôme** : le fantôme s'aligne sur les voisins.
4. **Verrouillage d'altitude** : **V**.
5. **Familles d'empreinte** :
   - *Bords* (mur, porte, fenêtre) : clé canonique partagée par les deux cases
     frontalières → anti-doublon.
   - *Centre* (fondation, toit, feu, coffre…): un par case et par niveau.

## 4. Éléments

`data/buildables/*.tres` : fondations, murs, portes, fenêtres, toits (plat,
pente, faîtage, coins), demi-murs, escaliers, coffres, feux de camp, tentes, lits,
fours, générateurs, maisons (kit).

## 5. Persistance

Les constructions sont sauvegardées dans le bloc `construction` du format v2 ;
les stations (feu de camp / four) sont recalculées au chargement.

## Voir aussi

- [`01-architecture.md`](01-architecture.md) — types de données
- [`10-sauvegarde-ui.md`](10-sauvegarde-ui.md) — persistance
- [`09-marche-repetition.md`](09-marche-repetition.md) — quêtes de construction
