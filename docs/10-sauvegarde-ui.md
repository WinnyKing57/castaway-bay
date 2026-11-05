# 10 — Sauvegarde, persistance, interface et commandes

## 1. Sauvegarde (`SaveSystem`)

- Format : JSON, version **2** (`user://savegame.json`), copie `.bak`.
- Bloc `player` : position, `rotation_y`, `pitch`, `in_boat`.
- Bloc `stats` / `inventory` / `hotbar_index` / `world_time` / `world_seed`.
- Bloc `craft` : fabrication en cours (ingrédients consommés).
- Bloc `construction` : éléments posés + stations.
- Bloc `world_state` : ressources épuisées (`regrow_left`), cultures,
  bateau/quad, marchand.
- Bloc `npc` : réputation, quêtes, journal.

## 2. Règles de validation

- Types, valeurs finies, version avant toute écriture.
- Inventaire assaini (objets inconnus, quantités ≤ 0 ignorés).
- Jauges bornées 0-100.
- Positions aberrantes replacées sur la plage.
- Sauvegardes v1 acceptées (champs manquants → valeurs par défaut).

## 3. Interface et commandes

- **Commandes** : voir [`../README.md`](../README.md) (section Commandes).
- **HUD** : santé, faim, soif, fatigue, horloge, hotbar, boussole (8 directions),
  stockage, crafting, marchand, journal, menus, réglages, mort.

## 4. Signaux `GameState`

`inventory_changed`, `hotbar_changed`, `toast`, `died`, `craft_changed`,
`chest_opened`, `trader_opened`, `reputation_changed`, `quests_changed`,
`journal_changed`.

## Voir aussi

- [`01-architecture.md`](01-architecture.md)
- [`11-tests.md`](11-tests.md) — couverture des signaux et persistance
