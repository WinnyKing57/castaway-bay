# 02 — Monde et carte

Ce document décrit le monde généré : île principale, relief, biomes, grottes,
îles secondaires et limites du monde.

## 1. Génération procédurale

`world/island.gd` génère l'île au démarrage :

- **Graine** : `GameState.world_seed`, mémorisée et sauvegardée → même relief
  au chargement.
- **Bruit** : `FastNoiseLite` (simplex, octaves) pour le relief
  (`_noise`, `_noise2`) et pour la répartition des biomes (`_biome_noise`).

## 2. Taille et dimensions

- `ISLAND_SIZE := 520.0` — île principale (~520 m de diamètre).
- `GRID_RES := 240` — résolution de la grille de terrain (subdivision).
- `world_radius()` → demi-largeur du monde (rayon ~260 m).

## 3. Biomes

Constantes `BIOME_*` :

| Constante | Valeur | Description |
|---|---|---|
| `BIOME_PLAINS` | 0 | Plaine herbeuse / herbe |
| `BIOME_FOREST` | 1 | Forêt dense (arbres serrés en bosquets) |
| `BIOME_WOODLAND` | 2 | Bocage (arbres + buissons) |
| `BIOME_HIGHLANDS` | 3 | Hautes terres / collines boisées |
| `BIOME_FARM` | 4 | Zone agricole dédiée (plateau plat) |
| `BIOME_BEACH` | 5 | Plage (sable, palmiers, argile, rochers) |
| `BIOME_PLAINS_PLATEAU` | 6 | Plateau agricole plat |
| `BIOME_MEADOW` | 7 | Préau fleuri (prairies claires) |
| `BIOME_MOUNTAIN` | 8 | Sommets rocheux |
| `BIOME_SECONDARY_ISLAND` | 9 | Île secondaire |

### 3.1 Détermination du biome

`_biome_at(x, z)` combine :

1. **Altitude** : plage (`< BEACH_MAX_HEIGHT`), sommets rocheux (`> 22 m`).
2. **Distance à l'île** : au-delà du rayon principal → biome secondaire.
3. **Distance à la ferme** : `FARM_RADIUS` autour de `_farm_center`.
4. **Secteur angulaire déformé par bruit** : `_sector_value(x, z)` → *sectors*
   multi-ensembles de 8 unités → biome.

`_sector_value` : `(atan2(z, x) + PI) / TAU` + warp bruital (`* 0.16`), multiplié
par 8 → 8 tranches de biomes sur l'angle du point.

### 3.2 Relief par biome

`_get_height_at` applique des pondérations par secteur :

- Forêt : relief légèrement adouci.
- Plateau agricole : aplati à ~3 m.
- Montagnes : accentuées (× 1.28).

La ferme est garantie plat (fondu progressif vers ~3 m).

## 4. Grottes

- `CAVE_COUNT := 8`, `CAVE_PROXIMITY := 5.0`.
- `_generate_caves()` : cavités sur flancs rocheux hauts (`height >= 10 m`),
  au moins une grotte garantie au sommet.
- `is_in_cave(position)` → pilotage de l'éclairage torche / ambiance sonore
  (`world/day_night.gd`, `main.gd`).

## 5. Îles secondaires

`_spawn_secondary_islands()` :

- 3 îlots secondaires à ~340 m du centre.
- Chaque îlot reçoit un biome parmi les plages / plateaux / prairies / montagnes.
- Ressources uniques par biome (palmiers, bananiers, minerais, cristaux…).
- **Épave de navire marchand** + survivant (voir [`09-marche-repetition.md`](09-marche-repetition.md)).

## 6. Limites du monde

- Le joueur est limité au cercle de `world_radius()` (via `Island.world_radius()`).
- Les véhicules et le marchand utilisent des bornes dynamiques (offset tolérant).
- Le point d'échouage du bateau (`find_boat_spawn_point()`) est généré sur l'eau
  près de la plage, selon l'altitude de surface.

## Voir aussi

- [`04-recolte.md`](04-recolte.md) — ressources récoltées selon les biomes
- [`10-sauvegarde-ui.md`](10-sauvegarde-ui.md) — sauvegarde du monde
