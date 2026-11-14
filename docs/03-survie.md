# 03 — Survie : santé, faim, soif, fatigue

Système de survie géré par l'autoload **`GameState`** (`autoload/game_state.gd`).

## 1. Les jauges

| Jauge | Démarrage | Décrémentation (par seconde de jeu) | Plage | Rôle |
|---|---|---|---|---|
| `health` | 100 | — | 0-100 | Vie ; 0 = mort |
| `hunger` | 100 | -0.08 | 0-100 | Faim ; ≤ 0 → perte de vie |
| `thirst` | 100 | -0.12 | 0-100 | Soif ; ≤ 0 → perte de vie |
| `fatigue` | 100 | -0.015 (récupère +0.05) | 0-100 | Fatigue ; ≤ 0 → perte de vie |

## 2. Évolution (ordre des checks dans `GameState._process`)

1. **Faim / soif** diminuent constamment.
2. Si `hunger <= 0` ou `thirst <= 0` → `health -= delta * 1.0`.
3. Si `health > 0` et `hunger > 60` et `thirst > 60` et `health < 100` → régénération
   santé (`+delta * 0.6`, plafonné à 100).
4. **Fatigue** se régénère lentement si faim/soif saines ; passe en « fatigué » à ≥ 100.
5. Si `fatigue <= 0` → `health -= delta * 0.5`.

## 3. Mort et respawn

- `health <= 0` → `is_dead = true`, signal `died`.
- Respawn : `GameState.respawn()` remet les stats de base, joueur remis au
  point d'apparition (`Island.find_spawn_point()`), contrôles réactivés.
- Noyade : la noyade peut tuer (d'autres lots : apnée, naufrage).

## 4. Consommation

`GameState.use_selected_item()` (via la barre rapide, touche **F**) applique les
soins d'un `ItemData` :

- `hunger_restore`, `thirst_restore`, `health_restore`, `fatigue_restore`.
- Plafonnés à 100.

## 5. Équilibrage (valeurs de base)

- Faim : -0.08/s (~83 s pour vider un estomac plein).
- Soif : -0.12/s (~69 s).
- Régénération fatigue : +0.05/s dès que les autres jauges sont au-dessus des seuils.

## Voir aussi

- [`04-recolte.md`](04-recolte.md) — manger / boire les objets récoltés
- [`08-agriculture.md`](08-agriculture.md) — culture et survie alimentaire
