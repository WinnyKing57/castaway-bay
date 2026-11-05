# 08 — Agriculture : semis, croissance, irrigation

Système de cultures basé sur les **crops** (`world/crop.gd`) et les graines
(`seed`) récoltées.

## 1. Semis

- Graines récoltées (`seed`) → semis sur le sol (zone agricole).
- `Crop.item_id` définit la culture (ex. `berry`).

## 2. Croissance

- Progression stockée (`GameState.world_time` / `Crop.progress`).
- Visuelle : teinte rouge à maturité.
- Récolte pérenne : +2 récoltes + 1 graine.

## 3. Irrigation / eau

- **Non implémenté** pour l'instant (voir [`TODO.md`](../TODO.md), lot E) :
  arrosage via récipients d'eau douce ou pluie.

## 4. Variétés

- **Non implémenté** pour l'instant : plusieurs variétés de cultures (maïs, blé,
  herbes médicinales).

## Voir aussi

- [`04-recolte.md`](04-recolte.md) — graines et récoltes
- [`03-survie.md`](03-survie.md) — agriculture comme source de nourriture
- [`TODO.md`](../TODO.md) — lots restants
