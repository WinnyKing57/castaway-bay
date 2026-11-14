# 05 — Artisanat : recettes et fabrication

Système piloté par **`RecipeData`** (`data/recipes/*.tres`) et **`GameState.craft()`**.
Le contenu est **data-driven** : ajouter une recette = créer un `.tres`, aucun code
à écrire.

## 1. Recettes

| Champ | Rôle |
|---|---|
| `inputs` | Dictionnaire `item_id → quantité` nécessaires (ex. `{"wood": 2, "fiber": 2}`) |
| `outputs` | Dictionnaire `item_id → quantité` produite |
| `craft_time` | Durée en secondes ; `0` = instantané |
| `required_station` | Station requise (`""` = nulle, `campfire`, `furnace`) |
| `category` | `survie`, `outils`, `cuisine`, `materiels`, `construction`, `electricite`, `agriculture`, `navigation` |
| `tier` | Palier de progression (1 → 4) |
| `unlocked_by` | Objet possédé, station disponible, quête accomplie ou `level:N` qui débloque la recette (`""` = connue) |
| `batch_size` | Multiplicateur de production (1 = normal) |

Le jeu contient **48 recettes** pour **64 objets**, réparties sur les huit
catégories. Chaînes de progression notables :

- **Bois** : `stick` → `handle` → `stone_pickaxe` / `fishing_rod` ;
- **Métal** : `iron_ingot` (four) → `nail` / `gear` / `iron_axe` ;
- **Électricité** : `wire` → `circuit` → `battery` / `lamp` ;
- **Construction** : `mortar` → `concrete`, `plank` → `beam`, `canvas` → `sail` ;
- **Acier** (paliers 4, verrouillés par niveau) : `iron_ingot` + charbon →
  `steel_ingot`, puis `steel_axe` / `steel_pickaxe` ;
- **Cuisine** : `bread`, `soup`, `grilled_corn`, `herbal_tea`, `dried_meat`,
  `fruit_salad` (objets consommables : faim / soif / vie / fatigue).

## 2. Fabrication chronométrée

1. `GameState.craft(recipe)` consomme les ingrédients **au lancement**.
2. `craft_time` s'incrémente via `GameState._advance_craft(delta)`.
3. `GameState.is_crafting()` garde la fabrication en file (1 seule à la fois).
4. Annulation depuis le panneau : ingrédients **rendus**, objet supprimé.
5. Reprise après un chargement (les ingrédients consommés sont persistés).
6. `batch_size` multiplie la quantité produite à la fin de la fabrication.

## 3. Outils

- **Hache en pierre** (`stone_axe`) : double le rendement du bois (2×).
- Les autres outils (pioches, pelle, couteau, hache en fer…) sont des objets de
  progression et de troc ; leurs usages spécifiques arrivent avec les systèmes
  de récolte avancée.
- **Kit de réparation** : réservé aux réparations d'ouvrages.
- **Bougie / Lanterne / Ampoule** : éclairage portatif (données prêtes).

## 4. Interface (`C`)

Le panneau `CraftingPanel` est construit en trois zones :

1. **Filtres** : onglets par catégorie (uniquement celles qui ont des recettes)
   + champ de recherche (nom, description, sortie).
2. **Liste** : une ligne par recette, icône procédurale (`IconFactory`), sortie
   et coût ; couleur = disponible / ressources manquantes / verrouillée.
3. **Détail** : icône, nom, catégorie, palier, description, sortie, ingrédients
   avec `possédé/requis` (vert/rouge), durée, station (disponible ou absente),
   condition de déblocage, sélecteur de quantité (`×1`, `×5`, `×10`, `Max`) et
   bouton **Fabriquer**.

Barre de progression et bouton **Annuler la fabrication** pendant une
fabrication chronométrée. `Échap` ou `C` ferme le panneau, `F1` affiche l'aide.

Les recettes sont triées par catégorie, puis palier, puis nom. Les recettes
verrouillées restent visibles (grisées) avec leur condition.

## 5. Tests

`./run.sh --test` vérifie notamment :

- au moins 40 recettes et 50 objets chargés ;
- catégories non vides et références croisées valides (ingrédients / sorties) ;
- fabrication, `batch_size`, sélection/filtres/recherche du panneau ;
- déblocage par objet, station ou quête ;
- fabrication par lot via l'interface et annulation (ingrédients rendus).

## Voir aussi

- [`01-architecture.md`](01-architecture.md) — types de données
- [`06-construction.md`](06-construction.md) — stations (feu de camp / four)
- [`12-donnees.md`](12-donnees.md) — modèle de données et icônes
- [`09-marche-repetition.md`](09-marche-repetition.md) — quêtes liées à la fabrication
