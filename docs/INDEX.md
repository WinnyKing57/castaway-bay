# Castaway Bay — Documentation

Documentation française complète du fonctionnement du jeu et de ses systèmes.

> Contenu de cette suite : comment chaque système, objet et mécanique fonctionne,
> en jeu et en code. Couvre l'architecture, le monde, la survie, la récolte,
> l'artisanat, la construction, les véhicules, l'agriculture, le commerce / la
> réputation / les quêtes, la sauvegarde, l'interface et les tests.

## Sommaire

| # | Document | Contenu |
|---|---|---|
| 1 | [`01-architecture.md`](01-architecture.md) | Architecture du projet, 4 règles, autoloads, données (`.tres`) |
| 2 | [`02-monde.md`](02-monde.md) | Monde procédural : île, relief, biomes, grottes, îles secondaires |
| 3 | [`03-survie.md`](03-survie.md) | Survie : santé, faim, soif, fatigue, mort et respawn |
| 4 | [`04-recolte.md`](04-recolte.md) | Récolte : ressources, biomes, loot, répousses |
| 5 | [`05-artisanat.md`](05-artisanat.md) | Artisanat : recettes, fabrication chronométrée, outils |
| 6 | [`06-construction.md`](06-construction.md) | Construction : mode, grille, fantôme, niveaux, undo |
| 7 | [`07-vehicules.md`](07-vehicules.md) | Véhicules : bateau, quad, navigation, carburant, épave |
| 8 | [`08-agriculture.md`](08-agriculture.md) | Agriculture : semis, croissance, irrigation, variétés |
| 9 | [`09-marche-repetition.md`](09-marche-repetition.md) | Marché : marchand, troc, quêtes, réputation, journal |
| 10 | [`10-sauvegarde-ui.md`](10-sauvegarde-ui.md) | Sauvegarde / persistance, interface, commandes |
| 11 | [`11-tests.md`](11-tests.md) | Tests, smoke test, outils de développement |
| 12 | [`12-donnees.md`](12-donnees.md) | Modèle de données (items, recettes, constructibles) et icônes |
| 13 | [`13-inventaire-hud.md`](13-inventaire-hud.md) | Inventaire, barre rapide, glisser-déposer et HUD |
| 14 | [`14-progression.md`](14-progression.md) | XP, niveaux, déblocage par niveau et sommeil |
| 15 | [`15-world-npc.md`](15-world-npc.md) | Marchand itinérant + survivant du navire marchand (kind, dialogue distinct) |
| — | [`DECISIONS.md`](DECISIONS.md) | Journal des décisions techniques |

## Comment lire cette documentation

- **Fonctionnement d'un système** : ouvrir le document correspondant ; chaque
  système y explique ses entrées (ce qui le déclenche), ses sorties (ce qu'il
  produit) et ses états.
- **Ajout d'un nouvel objet** : se référer à [`01-architecture.md`](01-architecture.md)
  (data-driven), puis au système concerné. Généralement : créer un `.tres`,
  enregistrer l'entrée dans `Database`, brancher via `interact()` / signaux.

## État de la documentation

- ✅ Documentation des lots livrés (M0 → M6 + améliorations).
- ✅ Modèle de données v3, icônes procédurales et sauvegarde v3 documentés.
- ✅ Interface d'artisanat, ergonomie de construction, inventaire et HUD v3 documentés.
- 🟡 Lots en cours : lots restants listés dans [`TODO.md`](../TODO.md).
- ⬜ Lots non implémentés documentés comme pistes dans [`TODO.md`](../TODO.md).

## Conventions utilisées dans les docs techniques

- **Noms de code** : tels qu'écrits dans le dépôt (ex. `GameState`, `island.gd`,
  `BIOME_FOREST`).
- **Touches** : en gras dans le texte (**B**), nom d'action en `code` dans les
  extraits techniques.
- **Langue** : français, aligné sur les commentaires de code.
