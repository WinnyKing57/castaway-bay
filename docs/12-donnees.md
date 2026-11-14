# Castaway Bay — Modèle de données et icônes

> Systèmes couverts : définitions `.tres` (`ItemData`, `RecipeData`,
> `BuildableData`), champs de catégorisation / paliers / déblocage,
> `IconFactory` (icônes procédurales) et cohérence des données au démarrage.

## Principes

Tout le contenu du jeu est **data-driven** : un objet, une recette ou un
constructible est une ressource `.tres` dans `data/items/`, `data/recipes/` ou
`data/buildables/`. `Database` charge ces dossiers au démarrage et expose les
dictionnaires `items`, `recipes`, `buildables` (clé = `id`).

Ajouter du contenu = créer un `.tres`, aucun code à écrire. Les champs ajoutés
en Phase 1 ont tous une **valeur par défaut** : une ressource ancienne reste
chargeable même si elle ne les déclare pas.

## `ItemData` (`data/item_data.gd`)

| Champ | Rôle |
|---|---|
| `id`, `display_name`, `description` | identité de l'objet |
| `category` | `ressource`, `outil`, `nourriture`, `materiel`, `construction`, `divers` |
| `max_stack`, `value` | pile max et valeur marchande |
| `tags` | mots-clés libres (`Array[String]`) pour filtrer / regrouper |
| `rarity` | `commun`, `rare`, `epique` |
| `icon_color` | couleur de l'icône générée |
| `icon_shape` | `cercle`, `carre`, `losange`, `goutte`, `feuille`, `lingot`, `buche`, `outil` |
| `weight` | poids unitaire (réservé aux systèmes de charge) |

## `RecipeData` (`data/recipe_data.gd`)

| Champ | Rôle |
|---|---|
| `id`, `display_name`, `description` | identité de la recette |
| `inputs`, `outputs` | `item_id -> quantité` |
| `craft_time` | durée de fabrication (s) |
| `required_station` | station requise (`""` = à la main) |
| `category` | `survie`, `outils`, `cuisine`, `materiels`, `construction`, `electricite`, `agriculture`, `navigation` |
| `tier` | palier de progression |
| `unlocked_by` | id qui débloque la recette (`""` = disponible) |
| `batch_size` | quantité produite par fabrication (1 par défaut) |

## `BuildableData` (`data/buildable_data.gd`)

| Champ | Rôle |
|---|---|
| `id`, `display_name`, `description` | identité du constructible |
| `kind` | visuel construit par `world/buildable.gd` |
| `costs`, `grid_size` | coût en objets et empreinte sur la grille |
| `category` | `fondations`, `murs`, `ouvertures`, `toits`, `escaliers`, `mobilier`, `stations`, `energie`, `defense`, `exterieur` |
| `tier` | palier (bois → pierre → brique → métal) |
| `upgrade_to` | id du palier suivant (`""` = aucun) |
| `health` | points de vie (défaut 100) |
| `unlocked_by` | id qui débloque (`""` = disponible) |
| `preview_scale` | échelle de la vignette de prévisualisation |

## `IconFactory` (`ui/icon_factory.gd`)

Génère les icônes **sans aucun asset externe** et les met en cache :

- `get_item_icon(item) -> Texture2D` : image 64 × 64 transparente dessinée
  pixel par pixel (`Image` + `set_pixel`), forme = `icon_shape`, couleur =
  `icon_color`, liseré sombre pour `rare` / `epique`.
- `get_buildable_icon(buildable) -> Texture2D` : vignette 64 × 64 dont la forme
  dérive de `kind` et la couleur de `tier`.

Les deux méthodes sont synchrones, sans dépendance au rendu GPU (elles
fonctionnent en headless, donc testables par le smoke test). Les textures sont
créées une seule fois par `id` puis réutilisées : aucun coût par frame.

> Décision : le rendu 3D via `SubViewport` a été écarté, voir
> [`DECISIONS.md`](DECISIONS.md).

## Cohérence des données (smoke test)

À chaque `./run.sh --test`, le smoke test vérifie :

- qu'aucun item, recette ou constructible n'a une `category` vide ;
- qu'aucun item n'a de tag vide ;
- que tout ingrédient de recette référence un `item_id` existant ;
- que toute sortie de recette référence un item **ou** un constructible existant.

Toute régression de contenu fait donc échouer le test avant le commit.

## Migration des `.tres` existants

Les ressources historiques ont reçu les nouveaux champs avec des valeurs
cohérentes (catégories par type, palier 1, style d'icône par objet). La
migration est un one-shot : le format courant est directement lisible, aucune
migration n'est nécessaire à l'exécution.
