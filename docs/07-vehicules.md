# 07 — Véhicules : bateau et quad

Deux véhicules : le **bateau** (océan) et le **quad** (relief).

## 1. Bateau (`world/boat.gd` — classe `Boat`)

- **Navigation** : gouvernail directionnel (rotation) + propulsion indépendante
  (acceleration / freinage / reverse).
- **Carburant** : réservoir 30, un `fuel` (bidon) par item. Réparation de la coque :
  1 `metal`.
- **Spawn** : `Island.find_boat_spawn_point()` — sur l'eau près de la plage,
  selon l'altitude de surface.

## 2. Quad (`world/quad.gd` — classe `Quad`)

- Véhicule terrestre : pilotage, emboard / exit, sauvegarde.
- Collision adaptée au sol.

## 3. Interaction et libération

- É (interaction) : monter / descendre, libération propre du joueur
  (sortie forcée = auto-sortie).
- Le joueur peut nager : le bateau suit via `in_boat`.

## 4. Limites du monde

- Les véhicules sont bornés par `Island.world_radius()` (via `/root/Main/World`).

## 5. Épave de navire

- Générée avec un survivant (`Trader`) — voir
  [`09-marche-repetition.md`](09-marche-repetition.md).

## Voir aussi

- [`02-monde.md`](02-monde.md) — spawn et limites
- [`10-sauvegarde-ui.md`](10-sauvegarde-ui.md) — persistance véhicule
