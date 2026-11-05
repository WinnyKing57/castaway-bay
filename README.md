# Castaway Bay

Jeu de survie / construction sur une île déserte, développé avec **Godot 4.7**.
Remake libre et original, inspiré des jeux de survie insulaire (aucun asset
ni code d'un jeu commercial n'est utilisé).

> État actuel : **M0 à M4 terminés**, M1 partiel (nage, sons synthétisés),
> M5 partiel (bateau et quad opérationnels, îlots secondaires à venir),
> M6 partiel (marchand, troc, quêtes, réputation et journal livrés ; épave de
> navire marchand à venir) et M7 partiel (réglages, export Linux) —
> île procédurale, océan, cycle jour/nuit, joueur FPS, récolte, survie,
> artisanat avancé, construction modulaire, véhicules, **persistance complète
> (format v2)** et sauvegarde automatique.

---

## Boucle de jeu

1. **Récolter & Explorer** : arbres (bois), palmiers (bois + noix de coco),
   rochers (pierre), buissons (fibres, parfois baies), affleurements de fer
   (métal), gisements côtiers (argile) et parcelles sauvages (graines).
2. **Survivre & Cultiver** : la faim, la soif et la fatigue évoluent
   constamment. Mange et bois avec la barre rapide (**1-5** puis **F**).
   Maintiens tes jauges au-dessus de 60 pour régénérer la fatigue. Plante des
   graines sur les parcelles agricoles : la culture grandit, vire au rouge à
   maturité et fournit 2 récoltes + 1 graine pour pérenniser les plantations.
3. **Fabriquer & Transformer** : **C** ouvre l'artisanat complet (hache en
   pierre qui double le rendement du bois, torches, planches, cordes, briques
   cuites, composants électroniques et carburant). Les fabrications peuvent être
   chronométrées et continuent en arrière-plan.
4. **Construire son abri** : **B** active le mode construction (fondations,
   murs, portes, fenêtres, toits, coffres, feux de camp, tentes, lits, fours et
   générateurs). Clic gauche pose, **R** fait pivoter, la molette change
   d'élément, **PgUp / PgDn** changent d'étage et **V** verrouille l'altitude.
5. **Naviguer** : repère le bateau échoué au large, répare sa coque avec du
   métal, fais le plein de carburant et navigue pour explorer les pourtours de
   l'océan. Un quad tout-terrain permet aussi de parcourir les reliefs.
6. **Troquer & tenir le journal** : trouve l'automate marchand et parle-lui
   (**E**). Sa réputation débloque des trocs directs et des quêtes
   d'approvisionnement (bois, nourriture, minerai, denrées rares). Les échanges
   et les quêtes rendues augmentent la réputation. **J** ouvre le livre de bord
   qui retrace les découvertes, les quêtes et les grands événements de survie.
7. **Sauvegarder & Reprendre** : **F9** / **F10**, plus une **sauvegarde
   automatique** (toutes les 2 min, en quittant vers le menu, à la fermeture de
   la fenêtre et quand l'appli passe en arrière-plan). Tout est conservé :
   graine de l'île, position, cap et regard du joueur, jauges, inventaire, barre
   rapide, fabrication en cours, constructions, ressources récoltées (et leur
   délai de repousse), cultures plantées, position et carburant des véhicules,
   réputation, quêtes, journal d'aventure et état du marchand. « Continuer » te
   ramène exactement où tu étais.

L'océan se traverse à la nage : au-delà de la taille, le joueur flotte et
peut nager (Espace pour remonter). Les sons sont synthétisés à la volée,
aucun fichier audio n'est nécessaire.

### Marchand, réputation et journal

L'automate marchand propose deux activités, toutes deux pilotées par les données
(`data/trades/` et `data/quests/`) :

- **Troc direct** : donne des ressources, reçois-en d'autres. Chaque échange
  rapporte 1 point de réputation et les offres les plus intéressantes exigent un
  palier de confiance (Méfiant, Neutre, Amical, Allié).
- **Quêtes d'approvisionnement** : accepte une commande, rapporte les objets
  demandés, puis rends-la au marchand pour une récompense et un gain de
  réputation plus important. Une quête ne peut être accomplie qu'une fois.
- **Livre de bord** (**J**) : journal chronologique des rencontres, découvertes,
  quêtes, morts et paliers de réputation. Il est conservé dans la sauvegarde et
  limité aux 120 entrées les plus récentes.

Le panneau du marchand affiche son dialogue (qui évolue avec la réputation et
les quêtes prêtes à rendre), les trocs accessibles et l'état de chaque quête.

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
- persistance : position/regard du joueur, ressources, cultures, bateau,
  fabrication en cours, stations, copie de secours `.bak` ;
- artisanat : fabrication chronométrée, annulation avec remboursement ;
- construction : chevauchements entre catégories (coffre/feu/toit sur une
  fondation), bords de murs/portes, empreintes conservées après chargement ;
- sauvegarde : fichiers malformés rejetés sans toucher à l'état, quantités et
  objets invalides assainis, doublons de constructions ignorés ;
- marchand : bornes de réputation, troc verrouillé/déverrouillé, gain de
  réputation, acceptation et remise de quête, récompenses, journal, ouverture et
  fermeture des panneaux, persistance de la rencontre et du compteur d'échanges ;
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
| J | ouvrir / fermer le livre de bord |
| C | ouvrir / fermer l'artisanat |
| B | activer / quitter le mode construction |
| R | tourner l'élément en cours de construction |
| Molette | changer d'élément à construire |
| PgUp / PgDn | changer le niveau de construction |
| V | verrouiller le niveau de construction |
| Clic gauche | poser l'élément (mode construction) |
| F9 | sauvegarder |
| F10 | charger |
| Échap | pause (reprendre, sauvegarder, réglages, menu principal) |
| Espace | réapparaître après la mort |

---

## Règles de construction avancées

Le système de construction modulaire suit des règles physiques et structurelles
réalistes :

1. **Ancrage au sol et contiguïté** :
   - Une première pièce au sol (niveau 0) doit obligatoirement être ancrée sur
     la terre ferme (hors des abysses marins).
   - Les fondations et structures suivantes peuvent s'étendre au-dessus de l'eau
     à condition d'être adjacentes à un élément déjà posé.
2. **Gestion des étages & support vertical** :
   - La hauteur d'élévation se règle par paliers (**PgUp / PgDn**).
   - Pour poser un élément en hauteur (étage ≥ 1), la cellule doit impérativement
     posséder une fondation ou un support au niveau inférieur. Impossible de
     construire dans le vide.
3. **Alignement et verrouillage d'altitude** :
   - En approchant une structure existante, le fantôme de prévisualisation
     s'aligne automatiquement sur le niveau de la pièce voisine.
   - La touche **V** permet de verrouiller l'altitude actuelle pour bâtir des
     passerelles ou des plateformes parfaitement planes sur un terrain vallonné.
4. **Catalogue et empreinte** :
   - Fondations, murs, portes, fenêtres, toits, tentes, feux de camp, coffres,
     fours, lits et générateurs électriques.
   - Le `grid_size` est respecté (la tente et le lit occupent 2 x 2 cases) et un
     élément ne peut pas être posé sur le joueur.

---

## Réglages & options de triche (mode créatif)

Accessible depuis le menu pause ou l'écran principal (**Échap ▸ Réglages**) :

- **Audio & Sensibilité** : curseurs de volume global et de sensibilité de la
  souris, appliqués immédiatement et persistés dans `user://settings.cfg`.
- **Affichage** : bascule plein écran / fenêtré.
- **Mode créatif (Matériaux infinis)** : option de triche permettant de
  fabriquer et construire sans consommer de composants. Elle peut être activée
  ou désactivée à tout moment sans corrompre la sauvegarde.

---

## Sources d'inspiration

Le design et l'architecture du jeu s'appuient sur deux projets externes
(non inclus dans ce dépôt) :

- [tomlooman/ActionRoguelike](https://github.com/tomlooman/ActionRoguelike) — gameplay
  action, systèmes de capacités, feedback et architecture de jeu.
- [tomlooman/EpicSurvivalGame](https://github.com/tomlooman/EpicSurvivalGame) — survie,
  habitation, inventaire, ressources.

Détails, conventions d'intégration et lots inspirés : voir
[`docs/INSPIRATION.md`](docs/INSPIRATION.md).

---

## Structure du projet

```
autoload/        singletons globaux (état, base de données, sauvegarde, audio)
data/            définitions de données : ItemData, RecipeData, BuildableData,
                 QuestData, TradeData + .tres (items, recipes, buildables,
                 quests, trades)
player/          contrôleur joueur (scène + script)
world/           île procédurale, ressources, cultures, véhicules, océan, marchand
systems/         mode construction (grille, aperçu fantôme, sauvegarde)
ui/              HUD, artisanat, coffres, marchand, journal, menus
main.tscn/.gd    assemblage de la scène de jeu
```

### Les 4 règles d'architecture

1. **Data-driven** : un objet, une recette, un constructible, une quête ou un
   troc = un fichier `.tres` dans `data/items/`, `data/recipes/`,
   `data/buildables/`, `data/quests/` ou `data/trades/`.
   Aucun code à écrire pour en ajouter.
2. **Interface plutôt que types** : tout ce qui est interactif expose
   `interact(player)` et `get_interaction_prompt()`. Le joueur ne connaît
   aucun type concret.
3. **État global centralisé** : `GameState` (inventaire, jauges, horloge)
   émet des signaux ; l'UI écoute, elle ne modifie rien.
4. **Sauvegarde en données, pas en scènes** : JSON versionné
   (`user://savegame.json`). La version actuelle du format est **2** ; les
   sauvegardes de version 1 restent acceptées et les champs ajoutés sont chargés
   avec des valeurs par défaut lorsqu'ils sont absents.

---

## Feuille de route

| Jalon | Contenu | État |
|---|---|---|
| M0 | Socle : projet, île, joueur, récolte, inventaire, sauvegarde | ✅ |
| M1 | Eau/nage, grottes, plusieurs biomes, ambiance sonore | 🟡 |
| M2 | Survie complète : faim, soif, fatigue, mort/respawn, consommation | ✅ |
| M3 | Artisanat : interface, recettes, outils | ✅ |
| M4 | Construction : grille, fondations, murs, niveaux, fantôme | ✅ |
| M5 | Véhicules : bateau opérationnel ; véhicule terrestre à venir | 🟡 |
| M6 | PNJ, quêtes, commerce, réputation | 🟡 |
| M7 | Finition : réglages et export Linux validés ; page itch.io à venir | 🟡 |

Le détail des idées non planifiées est dans [`IDEAS.md`](IDEAS.md).

Légende : ✅ terminé · 🟡 partiel · ⬜ à faire

---

## Stabilité et robustesse

Garde-fous en place (voir `./run.sh --test`) :

- **Inventaire** : `remove_item()` refuse toute quantité ≤ 0 ; `has_items()` /
  `consume_items()` refusent les coûts ≤ 0 (donnée corrompue).
- **Construction** : `grid_size` est respecté (tente et lit occupent 2 x 2
  cases) et un élément ne peut pas être posé sur le joueur. L'occupation d'une
  case ne dépend plus de la catégorie du bâtiment. Deux familles : *éléments de
  bord* (mur, porte, fenêtre : clé canonique partagée par la frontière de deux cases,
  empêchant les doublons ou superpositions de mur/porte de part et d'autre) et
  *éléments de centre* (fondation, toit, feu, coffre… : un par case et par niveau).
  La prévisualisation fantôme des arêtes s'aligne fidèlement et la clé est recalculée
  depuis la position réelle, donc identique avant et après une sauvegarde.
- **Coffres de stockage** : stockage persistant d'objets (touche **E** pour ouvrir),
  interface intuitive de dépôt et retrait (+1 / Tout), boutons de transfert global,
  persistance du contenu dans les sauvegardes v2.
- **Marchand, quêtes et journal** : réputation bornée à 0-100, trocs et quêtes
  refusés si les ressources ou la réputation manquent, quêtes non répétables,
  identifiants inconnus et entrées de journal invalides ignorés au chargement,
  panneaux qui se ferment proprement et rendent le contrôle au joueur.
- **Chargement des constructions** : l'identifiant doit exister dans la base
  (la catégorie vient de la base, pas du fichier), les coordonnées doivent être
  finies et bornées, les doublons sont ignorés, la station de fabrication
  (feu de camp / four) est restaurée.
- **Sauvegarde** : validation complète (types, valeurs finies, version) *avant*
  toute modification de l'état ; inventaire assaini (objets inconnus et
  quantités ≤ 0 ignorés), jauges bornées à 0-100, position aberrante replacée
  sur la plage. Rétrocompatibilité v1 testée et validée sans régression.
- **Bateau** : physique de navigation stabilisée avec gouvernail directionnel
  (rotation) et propulsion indépendante, point d'échouage généré sur l'eau
  près de la plage, réutilisation du carburant, libération propre du joueur.
- **Mode créatif** : l'option de matériaux infinis est prise en compte
  directement dans `has_items()` et `consume_items()`.
- **Données** : `chest`, `door`, `roof` et `window` déclarent leur `kind` (ils
  étaient auparavant construits comme des fondations).

### Persistance (sauvegarde v2)

`user://savegame.json` (version 2, les sauvegardes v1 se chargent toujours) :

| Bloc | Contenu |
|---|---|
| `player` | position, `rotation_y`, `pitch` (regard), `in_boat` |
| `stats`, `inventory`, `hotbar_index`, `world_time`, `world_seed` | état de survie et de la partie |
| `craft` | fabrication chronométrée en cours (ingrédients déjà consommés) |
| `construction` | éléments posés (id, position, rotation, stockage pour les coffres) ; stations recalculées |
| `world_state` | ressources épuisées (id stable + délai de repousse), cultures plantées (id + progression), bateau et quad (position, cap, carburant), marchand (position, rencontre, nombre d'échanges) |
| `npc` | réputation, quêtes acceptées/accomplies, livre de bord (bloc optionnel, absent des sauvegardes v1) |

Les ressources ont un identifiant stable (ordre de génération, déterministe pour
une graine). Ce qui n'est pas listé est remis à neuf au chargement.

Écriture sûre : fichier temporaire, ancienne sauvegarde conservée dans
`savegame.json.bak`, restaurée si l'écriture échoue ; si le fichier principal est
illisible, « Continuer » utilise la copie de secours. La sauvegarde automatique
n'écrit jamais depuis le menu principal ni pendant la mort.

### Artisanat chronométré

`craft_time` (secondes) est appliqué : les ingrédients sont pris au lancement,
la fabrication continue en arrière-plan même panneau fermé, peut être annulée
depuis le panneau (ingrédients rendus, aussi à la mort) et reprend après un
chargement. `craft_time = 0` reste instantané.

### Limites connues

- Une même recette ne peut pas être mise en file : une seule fabrication à la
  fois.
- Les transitions joueur/bateau, l'autosauvegarde à la fermeture de la fenêtre et
  le rendu sont à valider à la main avec fenêtre : le test sans fenêtre couvre la
  logique, pas l'affichage.
- Le panneau du marchand et le livre de bord sont couverts par les tests
  headless (ouverture, troc, quête, persistance) ; leur ergonomie et leur rendu
  restent à valider en session graphique.

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
