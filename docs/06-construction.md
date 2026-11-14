# 06 — Construction : mode, grille et éléments

Système piloté par le nœud **`Construction`** (`systems/construction.gd`).

## 1. Activation

- **B** : bascule le mode construction.
- Panneau HUD : catalogue filtrable (onglets de catégories + recherche),
  vignettes procédurales (`IconFactory`), palier, coûts `possédé/requis` en
  couleur et sélection par identifiant.
- **Tab** : roue de construction — les éléments de la catégorie courante sont
  disposés en cercle, un clic sélectionne l'élément (les contrôles du joueur
  restent suspendus en mode construction).

## 2. Grille et pose

- Grille de 1 m (cases).
- Clic gauche : pose ; **maintenir le clic** et survoler de nouvelles cases
  pose en série (une pose par case, jamais deux fois la même).
- **R** : rotation (0 / 90° / 180° / 270°).
- Molette : changement d'élément.
- Clic droit : **démolition** avec remboursement 75 % des matériaux.
- **Ctrl+Z** : annuler la dernière pose (remboursement intégral) ;
  **Ctrl+Y** : la rétablir (le coût est reconsommé, refusé si ressources
  insuffisantes). Une nouvelle pose vide la pile de rétablissement.

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

Les constructions sont sauvegardées dans le bloc `construction` de la
sauvegarde ; les stations (feu de camp / four) sont recalculées au chargement.

## 6. Ergonomie et tests

- Le panneau garde la sélection courante quand on change de catégorie ou de
  recherche ; les lignes restent cliquables même si les ressources manquent
  (l'état est affiché en rouge), pour permettre de préparer sa récolte.
- La roue (Tab) est purement visuelle : elle émet `buildable_chosen(id)` et le
  panneau/système de construction reste la seule source de vérité.
- Le smoke test vérifie : ouverture du panneau, filtres, recherche, sélection
  par id (et refus d'un id inconnu), contenu de la roue par catégorie, actions
  `build_wheel` et `redo_build` dans l'InputMap, annulation puis
  rétablissement d'une pose.

## 7. Limites connues

- L'ergonomie de la roue (positionnement radial, lisibilité) et la pose en
  série au clic maintenu restent à valider en session graphique : le test
  headless ne simule ni la souris ni le rendu.

## Voir aussi

- [`01-architecture.md`](01-architecture.md) — types de données
- [`10-sauvegarde-ui.md`](10-sauvegarde-ui.md) — persistance
- [`09-marche-repetition.md`](09-marche-repetition.md) — quêtes de construction
