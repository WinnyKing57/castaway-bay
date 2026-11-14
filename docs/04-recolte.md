# 04 — Récolte : ressources et biomes

Le système de récolte repose sur les **ressources** (`Harvestable`) générées sur
le monde et consommées via **`GameState`**.

## 1. Les kinds de ressources

Déclarés via `@export_enum(...)` dans `world/harvestable.gd` :

| Kind | Symbole | Loot (récolte) | Visuel |
|---|---|---|---|
| `arbre` | 🌳 | `wood: 3` | Arbre (tronc + cime) |
| `palmier` | 🌴 | `wood: 4` + `coconut: 2` | Palmier |
| `rocher` | 🪨 | `stone: 3` | Rocher |
| `buisson` | 🌿 | `fiber: 5` (+ `berry` parfois) | Buisson |
| `seed` | 🌱 | `seed: 2` | Graine |
| `fer` | ⛏️ | `metal: 2` | Affleurement de fer |
| `argile` | 🏺 | `clay: 3` | Gisement côtier |
| `cristal` | 💎 | `crystal: 2` | Cristal (profondeur) |
| `charbon` | 🪨 | `coal: 3` | Charbon (profondeur) |
| `or` | 🪙 | `gold: 4` | Or (profondeur) |

## 2. Loot et quantités

`interact(player)` décrémente la ressource (`is_depleted = true`) et ajoute les
objets du loot à l'inventaire (`GameState.add_item`).

## 3. Répousse

- `REGROW_SECONDS := 120.0` (2 minutes) ; graines : 30 s.
- `Harvestable._regrow()` : la ressource repousse après délai.
- Persistée via le monde (`regrow_left`) pour ne pas re-spawner immédiatement après
  un chargement.

## 4. Rôle par biome

| Biome | Ressources présentes |
|---|---|
| Forêt | arbres, buissons, graines, rochers |
| Plaine | buissons, graines, arbres isolés, rochers |
| Bocage / hautes terres | arbres, buissons, rochers, fer |
| Plage | palmiers, argile, buissons, rochers |
| Montagnes / profondeurs | charbon, or, fer, cristal |

Les minerais rares (`cristal`, `fer`, `charbon`, `or`) sont garantis sur les sommets
(`_ensure_deep_minerals`) et tirés au-delà de 14 m de hauteur.

## Voir aussi

- [`02-monde.md`](02-monde.md) — où les ressources sont générées
- [`05-artisanat.md`](05-artisanat.md) — transformation en objets fabriqués
- [`03-survie.md`](03-survie.md) — faim/soif alimentées par la récolte
