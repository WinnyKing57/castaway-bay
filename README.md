# Castaway Bay

Jeu de survie / construction sur une île déserte, développé avec **Godot 4.7**.
Remake libre et original, inspiré des jeux de survie insulaire (aucun asset
ni code d'un jeu commercial n'est utilisé).

> État actuel : **M0 à M4 terminés**, M1 partiel (nage, sons synthétisés), passe de
> stabilisation appliquée —
> île procédurale, océan, cycle jour/nuit, joueur FPS, récolte, survie,
> artisanat, construction et sauvegarde.

---

## Boucle de jeu

1. **Récolter** : arbres (bois), palmiers (bois + noix de coco), rochers
   (pierre), buissons (fibres, parfois baies).
2. **Survivre** : la faim et la soif baissent en permanence. Mange et bois
   avec la barre rapide (**1-5** puis **F**).
3. **Fabriquer** : **C** ouvre l'artisanat (torche, hache en pierre).
   La hache double le bois récolté.
4. **Construire** : **B** active le mode construction (fondation, mur,
   feu de camp). Clic gauche pose, **R** tourne, molette change d'élément.
5. **Sauvegarder** : **F9** / **F10**, plus une **sauvegarde automatique**
   (toutes les 2 min, en quittant vers le menu, à la fermeture de la fenêtre et
   quand l'appli passe en arrière-plan). Tout est conservé : graine de l'île,
   position, cap et regard du joueur, jauges, inventaire, barre rapide,
   fabrication en cours, constructions, ressources récoltées (et leur délai de
   repousse), cultures plantées, position et carburant du bateau, et le fait
   d'être à bord. « Continuer » te ramène exactement où tu étais.

L'océan se traverse à la nage : au-delà de la taille, le joueur flotte et
peut nager (Espace pour remonter). Les sons sont synthétisés à la volée,
aucun fichier audio n'est nécessaire.

Au lancement, le **menu principal** propose de commencer une nouvelle île
ou de reprendre la sauvegarde existante.

---

## Lancer le jeu

### 1. Installer Godot 4.7

```bash
flatpak install flathub org.godotengine.Godot
```

Alternative : télécharger le binaire sur <https://godotengine.org/download>.

### 2. Ouvrir le projet

```bash
./run.sh            # ouvre l'éditeur Godot sur ce dossier
./run.sh --play     # lance le jeu directement
```

Puis **F5** dans l'éditeur pour lancer le jeu.

### 3. Test d'intégration (sans fenêtre)

```bash
./run.sh --test     # doit afficher : SMOKE_TEST OK
```

Le test couvre le socle (île, nage, récolte, artisanat, construction,
sauvegarde) **et** des tests de non-régression de stabilité :

- inventaire : retraits et coûts négatifs/nuls refusés ;
- persistance : position/regard du joueur, ressources, cultures, bateau, fabrication en cours, stations, copie de secours `.bak` ;
- artisanat : fabrication chronométrée, annulation avec remboursement ;
- construction : chevauchements entre catégories (coffre/feu/toit sur une
  fondation), bords de murs/portes, empreintes conservées après chargement ;
- sauvegarde : fichiers malformés rejetés sans toucher à l'état, quantités et
  objets invalides assainis, doublons de constructions ignorés ;
- bateau : libération du joueur après sortie forcée, réparation.

Le test sauvegarde puis restaure `user://savegame.json` et
`user://settings.cfg` : lancer `--test` n'écrase plus ta vraie partie.

### 4. Outils de développement

```bash
./run.sh --overview # vue aérienne de l'île générée (vérification du terrain)
```

---

## Commandes

| Touche | Action |
|---|---|
| ZQSD / WASD | se déplacer (physique, indépendant de la disposition du clavier) |
| Souris | regarder |
| Maj | courir |
| Espace | sauter |
| E | interagir / récolter |
| 1 à 5 | sélectionner un objet de la barre rapide |
| F | utiliser l'objet sélectionné (manger, boire) |
| C | ouvrir / fermer l'artisanat |
| B | activer / quitter le mode construction |
| R | tourner l'élément en cours de construction |
| Molette | changer d'élément à construire |
| PgUp / PgDn | changer le niveau de construction |
| V | verrouiller le niveau de construction |
| Clic gauche | poser l'élément (mode construction) |
| F9 | sauvegarder |
| F10 | charger |
| Échap | pause (reprendre, sauvegarder, menu principal) |
| Espace | réapparaître après la mort |

---

## Structure du projet

```
autoload/        singletons globaux (état, base de données, sauvegarde, audio)
data/            définitions de données : ItemData, RecipeData, BuildableData + .tres
player/          contrôleur joueur (scène + script)
world/           île procédurale, ressources récoltables, éléments construits, océan
systems/         mode construction (grille, aperçu fantôme, sauvegarde)
ui/              HUD, panneau d'artisanat, menus
main.tscn/.gd    assemblage de la scène de jeu
```

### Les 4 règles d'architecture

1. **Data-driven** : un objet, une recette ou un constructible = un fichier
   `.tres` dans `data/items/`, `data/recipes/` ou `data/buildables/`.
   Aucun code à écrire pour en ajouter.
2. **Interface plutôt que types** : tout ce qui est interactif expose
   `interact(player)` et `get_interaction_prompt()`. Le joueur ne connaît
   aucun type concret.
3. **État global centralisé** : `GameState` (inventaire, jauges, horloge)
   émet des signaux ; l'UI écoute, elle ne modifie rien.
4. **Sauvegarde en données, pas en scènes** : JSON versionné
   (`user://savegame.json`), avec un numéro de version pour migrer plus tard.

---

## Feuille de route

| Jalon | Contenu | État |
|---|---|---|
| M0 | Socle : projet, île, joueur, récolte, inventaire, sauvegarde | ✅ |
| M1 | Eau/nage, grottes, plusieurs biomes, ambiance sonore | 🟡 |
| M2 | Survie complète : faim, soif, mort/respawn, consommation | ✅ |
| M3 | Artisanat : interface, recettes, outils | ✅ |
| M4 | Construction : grille, fondations, murs, feu de camp, fantôme, niveaux | ✅ |
| M5 | Véhicules : bateau et voiture (physique simple) | 🟡 |
| M6 | PNJ, quêtes, commerce, réputation | ⬜ |
| M7 | Finition : réglages, export Linux + page itch.io | 🟡 |

Le détail des idées non planifiées est dans [`IDEAS.md`](IDEAS.md).

Légende : ✅ terminé · 🟡 partiel · ⬜ à faire

---

## Stabilité et robustesse

Garde-fous en place (voir `./run.sh --test`) :

- **Inventaire** : `remove_item()` refuse toute quantité ≤ 0 ; `has_items()` /
  `consume_items()` refusent les coûts ≤ 0 (donnée corrompue).
- **Construction** : `grid_size` est respecté (tente et lit occupent 2 x 2 cases) et un élément ne peut pas être posé sur le joueur. L'occupation d'une case ne dépend plus de la catégorie du
  bâtiment. Deux familles : *éléments de bord* (mur, porte, fenêtre : un par
  bord, niveau et orientation) et *éléments de centre* (fondation, toit, feu,
  coffre… : un par case et par niveau). La clé est recalculée depuis la
  position réelle, donc identique avant et après une sauvegarde.
- **Chargement des constructions** : l'identifiant doit exister dans la base
  (la catégorie vient de la base, pas du fichier), les coordonnées doivent être
  finies et bornées, les doublons sont ignorés, la station de fabrication
  (feu de camp / four) est restaurée.
- **Sauvegarde** : validation complète (types, valeurs finies, version) *avant*
  toute modification de l'état ; inventaire assaini (objets inconnus et
  quantités ≤ 0 ignorés), jauges bornées à 0-100, position aberrante replacée
  sur la plage. Un fichier invalide est refusé en bloc.
- **Bateau** : le joueur suit le bateau ; mort, respawn, nouvelle partie ou
  chargement le libèrent. Recharge automatique du carburant et réparation (1
  métal) corrigées.
- **Données** : `chest`, `door`, `roof` et `window` déclarent maintenant leur
  `kind` (ils étaient construits comme des fondations).

### Persistance (sauvegarde v2)

`user://savegame.json` (version 2, les sauvegardes v1 se chargent toujours) :

| Bloc | Contenu |
|---|---|
| `player` | position, `rotation_y`, `pitch` (regard), `in_boat` |
| `stats`, `inventory`, `hotbar_index`, `world_time`, `world_seed` | état de survie et de la partie |
| `craft` | fabrication chronométrée en cours (ingrédients déjà consommés) |
| `construction` | éléments posés (id, position, rotation) ; stations recalculées |
| `world_state` | ressources épuisées (id stable + délai de repousse), cultures plantées (id + progression), bateau (position, cap, carburant) |

Les ressources ont un identifiant stable (ordre de génération, déterministe pour
une graine). Ce qui n'est pas listé est remis à neuf au chargement.

Écriture sûre : fichier temporaire, ancienne sauvegarde conservée dans
`savegame.json.bak`, restaurée si l'écriture échoue ; si le fichier principal est
illisible, « Continuer » utilise la copie de secours. La sauvegarde automatique
n'écrit jamais depuis le menu principal ni pendant la mort.

### Artisanat chronométré

`craft_time` (secondes) est maintenant appliqué : les ingrédients sont pris au
lancement, la fabrication continue en arrière-plan même panneau fermé, peut être
annulée depuis le panneau (ingrédients rendus, aussi à la mort) et reprend après
un chargement. `craft_time = 0` reste instantané.

### Limites connues

- Une même recette ne peut pas être mise en file : une seule fabrication à la
  fois.
- Les coffres n'ont pas encore de contenu (rien à sauvegarder).
- Les transitions joueur/bateau, l'autosauvegarde à la fermeture de la fenêtre et
  le rendu sont à valider à la main avec fenêtre : le test sans fenêtre couvre la
  logique, pas l'affichage.

---

## Exporter pour Linux

1. Éditeur → **Éditeur ▸ Gérer les modèles d'exportation** → télécharger.
2. **Projet ▸ Exporter… ▸ Linux** (preset déjà configuré).
3. Sortie : `build/linux/castaway-bay.x86_64`.

Le binaire produit est autonome (PCK intégré), testable sur toute
distribution Linux x86_64 récente.

Vérification rapide (sans interface graphique) :

```bash
./build/linux/castaway-bay.x86_64 --headless -- --smoke-test
```

Doit afficher : `SMOKE_TEST OK`.

Côté projet, `./run.sh --test` passe aussi : `SMOKE_TEST OK`, 0 erreur
(validé en local et sur le device).

---

## Crédits et licence

- Code et design : à toi.
- Assets à venir : privilégier le **CC0** (Kenney, Quaternius, Poly Haven,
  ambientCG, Freesound) pour rester libre de toute redistribution.
- Ne pas réutiliser les assets, textes ou fichiers d'un jeu commercial.
