# 14 — Progression et sommeil

La progression est **globale** (pas de compétence par arme ni d'arbre de
talents) et vit dans `GameState`, donc elle est sauvegardée et l'interface se
contente de l'afficher.

## 1. XP et niveaux

| Constante | Valeur | Source |
|---|---|---|
| `XP_PER_HARVEST` | 4 | récolte d'une ressource (`world/harvestable.gd`) |
| `XP_PER_CRAFT` | 8 | fabrication terminée (`GameState._finish_craft`) |
| `XP_PER_BUILD` | 12 | pose d'un élément (`Construction._place`) |
| `XP_PER_QUEST` | 60 | quête accomplie (`GameState.complete_quest`) |
| `MAX_LEVEL` | 20 | plafond |

Courbe : `xp_for_next_level() = 60 + 40 × (niveau − 1)` (60 XP pour le niveau 2,
100 pour le 3, 140 pour le 4…). `level_progress()` renvoie l'avancement dans le
niveau courant (0 → 1) pour la jauge HUD.

Une montée de niveau :

1. retire le seuil de l'XP courante (l'excédent est conservé) ;
2. restaure la **fatigue** à 100 ;
3. notifie le joueur et écrit une entrée dans le livre de bord ;
4. émet `level_changed`.

Le rétablissement d'une pose annulée (`Ctrl+Y`) ne donne **pas** d'XP : sinon
l'annulation / rétablissement permettrait de farmer.

## 2. Déblocage par niveau

`RecipeData.unlocked_by` accepte une quatrième forme, `"level:N"` :

| `unlocked_by` | Débloquée si… |
|---|---|
| `""` | toujours |
| `"level:N"` | `GameState.level >= N` |
| id de constructible | la station est disponible (`has_station`) |
| id de quête | la quête est dans `completed_quests` |
| id d'objet | le joueur possède l'objet |

Le panneau d'artisanat affiche « Verrouillée : nécessite le niveau N » et
garde la recette visible. Contenu concerné :

- `steel_ingot` (four) → niveau 3 ;
- `steel_pickaxe` → niveau 4 ;
- `steel_axe` → niveau 5.

## 3. Sommeil

`GameState.sleep_until_morning()` est la seule logique de sommeil (le lit
l'appelle) :

- refusé le jour (`is_night()` = vrai entre **19 h et 6 h**) ;
- sinon : heure portée à **6 h**, fatigue à 100, vie +30 (plafonnée à 100) ;
- entrée dans le livre de bord et notification.

`hour_of_day()` / `is_night()` centralisent la lecture de `world_time`, pour que
le lit, l'éclairage et les futurs effets de nuit restent cohérents.

## 4. Sauvegarde

Bloc ajouté à la sauvegarde v3 (champ **optionnel**) :

```json
"progression": { "level": 4, "xp": 17 }
```

- absent (sauvegardes v1/v2 ou v3 antérieures) → `level = 1`, `xp = 0` ;
- validé par `SaveSystem._is_valid()` (dictionnaire + valeurs numériques) ;
- relu avec bornage `1 ≤ level ≤ MAX_LEVEL` et `xp ≥ 0`.

Aucun changement de numéro de version : le champ est optionnel et rétrocompatible
dans les deux sens (un ancien binaire ignore simplement le bloc).

## 5. Interface

- Ligne « Niv. N » + jauge violette d'XP dans le bloc de jauges du HUD
  (`Root/Stats/LevelRow`), mise à jour chaque image.
- Toast et journal à chaque niveau.
- Aide F1 et README ne changent pas : aucune nouvelle touche.

## 6. Tests

`./run.sh --test` vérifie :

- le gain d'XP de récolte et la montée de niveau (niveau 2, XP résiduelle 0) ;
- la courbe croissante et `level_progress()` ;
- la synchronisation du libellé et de la jauge HUD ;
- le refus du sommeil le jour, son effet la nuit (6 h, fatigue 100) ;
- le verrouillage / déverrouillage de `steel_ingot` à `level:3` ;
- la persistance de `level` / `xp` après sauvegarde et rechargement ;
- la remise à zéro lors de `GameState.reset()`.

## 7. Limites connues

- Pas d'arbre de talents ni de points à répartir : les niveaux servent de
  portes de contenu (recettes) et de repère de progression.
- Les outils en acier sont des données de progression ; leur effet de récolte
  spécifique n'est pas encore branché (seule la hache en pierre modifie le
  rendement du bois).

## Voir aussi

- [`03-survie.md`](03-survie.md) — jauges, mort, renaissance
- [`05-artisanat.md`](05-artisanat.md) — recettes et déblocage
- [`10-sauvegarde-ui.md`](10-sauvegarde-ui.md) — format et validation
