# 05 — Artisanat : recettes et fabrication

Système piloté par **`RecipeData`** (`data/recipes/*.tres`) et **`GameState.craft()`**.

## 1. Recettes

| Champ | Rôle |
|---|---|
| `inputs` | Dictionnaire `item_id → quantité` nécessaires (ex. `{"wood": 2, "fiber": 2}`) |
| `outputs` | Dictionnaire `item_id → quantité` produite |
| `craft_time` | Durée en secondes ; `0` = instantané |
| `required_station` | Station requise (`""` = nulle, `campfire`, `furnace`) |

Exemples : `torch` (2 bois + 2 fibres), `plank` (2 bois → 4 planches), `rope`
(4 fibres → 3 cordes), `baked_brick` (2 argile → 1 brique cuite), `electronics`
(fer + cristal → électronique), `fuel` (bois → carburant).

## 2. Fabrication chronométrée

1. `GameState.craft(recipe)` consomme les ingrédients **au lancement**.
2. `craft_time` s'incrémente via `GameState._advance_craft(delta)`.
3. `GameState.is_crafting()` garde la fabrication en file (1 seule à la fois).
4. Annulation depuis le panneau : ingrédients **rendus**, objet supprimé.
5. Reprise après un chargement (les ingrédients consommés sont persistés).

## 3. Outils

- **Hache en pierre** (`stone_axe`) : double le rendement du bois (2×).

## 4. Interface

- **C** ouvre le panneau d'artisanat (`CraftingPanel`).
- Boutons par recette, fabrication, annulation, progression.

## Voir aussi

- [`01-architecture.md`](01-architecture.md) — types de données
- [`06-construction.md`](06-construction.md) — stations (feu de camp / four)
- [`09-marche-repetition.md`](09-marche-repetition.md) — quêtes liées à la fabrication
