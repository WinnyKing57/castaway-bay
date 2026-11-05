# 01 — Architecture et données

Cette page explique comment le jeu est organisé : nœuds, autoloads, règles
d'architecture et format de données.

## 1. Vue d'ensemble de la scène principale

```
main.tscn (Node3D)
├── World            → Island (procédural)
├── Player          → CharacterBody3D (FPS)
├── HUD              → panneaux (hotbar, santé, inventaire, crafting, marchand, journal…)
├── Construction    → grille + fantôme + sauvegarde
├── Sun              → DirectionalLight3D + cycle jour/nuit
└── Camera
```

Les nœuds de gameplay ne connaissent pas les uns les autres par type concret :
ils passent par des **signaux** (`GameState`) ou des **interfaces** légères.

## 2. Les 4 règles d'architecture

1. **Data-driven** — un objet, une recette, un constructible, une quête ou un
   troc = un fichier `.tres` dans `data/`. Aucun code à écrire pour en ajouter un.
2. **Interface plutôt que types** — tout ce qui est interactif expose
   `interact(player: Node)` et `get_interaction_prompt() -> String`. Le joueur
   n'appelle que ces méthodes, jamais un type concret.
3. **État global centralisé** — `GameState` (autoload) centralise inventaire,
   jauges, horloge, réputation, quêtes, journal ; les signaux (`inventory_changed`,
   `hotbar_changed`, `toast`, `died`, `craft_changed`, `chest_opened`,
   `trader_opened`, `reputation_changed`, `quests_changed`, `journal_changed`)
   notifient les vues.
4. **Sauvegarde en données, pas en scènes** — JSON versionné (`user://savegame.json`,
   format actuel **v2**), jamais de scènes sérialisées.

## 3. Les autoloads

| Autoload | Rôle |
|---|---|
| `GameState` | État de partie : inventaire, stats, hotbar, horloge, réputation, quêtes, journal, signaux |
| `Database` | Charge et indexe les `.tres` (items, recettes, buildables, quêtes, trocs) |
| `SaveSystem` | Lecture/écriture JSON v2, validation, sauvegarde automatique |
| `Settings` | Réglages persistants (volume, sensibilité, plein écran, mode créatif) |
| `Sfx` | Synthèse audio à la volée + musique d'ambiance (day/dusk/night/cave) |
| `GameState` | Réputation, quêtes, journal (voir ci-dessus) |

## 4. Flux d'un objet interactif (récolte, troc, chest…)

```
Input (E) → Player.interact() → zone/objet → interact(player)
        → GameState.ou SaveSystem manipuler l'état
        → signaux → HUD/UI
```

- Le **player** détecte l'objet via un **raycast** (`Head` + interaction).
- L'objet retourné expose `interact(player)` et `get_interaction_prompt()`.
- Certains objets (ressources) délètent via **`GameState`** (inventaire) et
  émettent des signaux ; d'autres (coffre, marchand, lit…) manipulent des nœuds
  de scène dédiés et émettent leurs propres signaux (`chest_opened`, `trader_opened`).

## 5. Les types de données (`.tres`)

| Fichier | Type | Rôle |
|---|---|---|
| `data/items/*.tres` | `ItemData` | Identifiant, nom, catégorie, stack, soins (faim/soif/health/fatigue), valeur |
| `data/recipes/*.tres` | `RecipeData` | Ingrédients (`inputs` = item → quantité), sortie (`outputs`), temps, station requise |
| `data/buildables/*.tres` | `BuildableData` | `kind`, `grid_size`, `costs`, propriétés de collision |
| `data/quests/*.tres` | `QuestData` | Objectifs (`required_items`), récompenses, réputation minimale |
| `data/trades/*.tres` | `TradeData` | Échange (`give`/`receive`), ressources échangées, réputation requise |

### Ajouter un nouvel objet (ex. une ressource)

1. Créer `data/items/<id>.tres` avec les champs `ItemData`.
2. Mettre à jour le `Database` (il scanne le dossier : aucune modification de code).
3. Utiliser le `kind` correspondant dans `world/harvestable.gd` pour la géométrie.
4. L'UI (HUD/crafting) consomme l'`ItemData` : soins, stack, catégorie.

## 6. État global (`GameState`)

Structure clé :

```
GameState.inventory            # Dictionary item_id -> quantité
GameState.stats                # Dictionary : health / hunger / thirst / fatigue
GameState.hotbar_items         # Array[String] (IDs accessibles 1-5)
GameState.hotbar_index
GameState.world_time / GameState.SECONDS_PER_DAY  # horloge du monde (600 s = 10 min/jour)
GameState.world_seed           # graine de l'île
GameState.reputation           # 0-100
GameState.accepted_quests / completed_quests
GameState.journal              # Array[String] (max 120 entrées)
```

Fonctions clés : `add_item`, `remove_item`, `has_items`, `consume_items`,
`use_selected_item`, `craft(recipe)`, `advance_craft(delta)`.

## 7. Erreurs et invariants

- **Inventaire** : quantités ≤ 0 et objets inconnus ignorés.
- **Stats** : bornées 0-100, régénération selon les seuils (faim/soif > 60 → récupération santé).
- **Réputation** : bornée 0-100 (trop-plein → 100, trop-creux → 0).
- **Journal** : plafonné à `MAX_JOURNAL_ENTRIES` (120).

## Voir aussi

- [`02-monde.md`](02-monde.md) — génération du monde
- [`05-artisanat.md`](05-artisanat.md) — recettes
- [`10-sauvegarde-ui.md`](10-sauvegarde-ui.md) — format de sauvegarde
