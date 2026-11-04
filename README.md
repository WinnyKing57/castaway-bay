# Castaway Bay

Jeu de survie / construction sur une île déserte, développé avec **Godot 4.7**.
Remake libre et original, inspiré des jeux de survie insulaire (aucun asset
ni code d'un jeu commercial n'est utilisé).

> État actuel : **M0 à M5 terminés**, M7 export et réglages validés —
> île procédurale, océan, cycle jour/nuit, joueur FPS, récolte, survie,
> artisanat avancé, construction modulaire à étages, véhicule marin fonctionnel,
> menu complet de réglages et sauvegarde persistante.

---

## Boucle de jeu

1. **Récolter & Explorer** : arbres (bois), palmiers (bois + noix de coco), rochers
   (pierre), buissons (fibres, baies), affleurements de fer (métal), gisements côtiers
   (argile), parcelles sauvages (graines) et épaves échouées (viande + tissu).
2. **Survivre & Cultiver** : la faim, la soif et la fatigue évoluent constamment. Mangez
   et buvez avec la barre rapide (**1-5** puis **F**). Maintenez vos jauges au-dessus
   de 60 pour régénérer la fatigue. Plantez des graines sur les parcelles agricoles pour
   produire de la nourriture (la culture grandit, vire au rouge à maturité et produit à la
   fois 2 récoltes et 1 graine pour pérenniser vos plantations).
3. **Fabriquer & Transformer** : **C** ouvre l'artisanat complet (outils comme la hache en pierre
   qui double le rendement du bois, torches, planches, cordes, briques cuites, composants
   électroniques et carburant).
4. **Construire son abri** : **B** active le mode construction (fondations, murs, portes,
   fenêtres, toits, coffres, feux de camp, tentes, lits, fours et générateurs).
   Clic gauche pose, **R** fait pivoter, la molette change d'élément.
5. **Naviguer** : repérez le bateau échoué au large, réparez sa coque avec du métal, faites le plein
   de carburant et naviguez pour explorer les pourtours de l'océan.
6. **Sauvegarder & Reprendre** : **F9** / **F10** ou via le menu pause. La graine de l'île,
   l'inventaire, les constructions, le bateau (position, orientation, état de coque,
   carburant), les ressources récoltables et les cultures sont conservés.

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
| Échap | pause (reprendre, sauvegarder, réglages, menu principal) |
| Espace | réapparaître après la mort |

---

## Règles de construction avancées

Le système de construction modulaire suit des règles physiques et structurelles réalistes :

1. **Ancrage au sol et contiguïté** :
   - Une première pièce au sol (niveau 0) doit obligatoirement être ancrée sur la terre ferme (hors des abysses marins).
   - Les fondations et structures suivantes peuvent s'étendre au-dessus de l'eau à condition d'être adjacentes à un élément déjà posé.
2. **Gestion des étages & Support vertical** :
   - La hauteur d'élévation se règle par paliers (**PgUp / PgDn**).
   - Pour poser un élément en hauteur (étage ≥ 1), la cellule doit impérativement posséder une fondation ou un support au niveau inférieur. Il est impossible de construire dans le vide.
3. **Alignement et verrouillage d'altitude** :
   - En approchant une structure existante, le fantôme de prévisualisation s'aligne automatiquement sur le niveau de la pièce voisine.
   - La touche **V** permet de verrouiller l'altitude actuelle pour bâtir des passerelles ou des plateformes parfaitement planes sur un terrain vallonné.
4. **Catalogue d'éléments** :
   - Fondations, murs, portes, fenêtres, toits, tentes, feux de camp, coffres, fours, lits et générateurs électriques.

---

## Réglages & Options de triche (Mode créatif)

Accessible depuis le menu pause ou l'écran principal (**Échap ▸ Réglages**) :
- **Audio & Sensibilité** : curseurs de volume global et sensibilité de la souris avec application immédiate et persistance indépendante (`user://settings.cfg`).
- **Affichage** : bascule plein écran / fenêtré.
- **Mode créatif (Ressources infinies)** : option de triche intégrée permettant de fabriquer et construire sans consommer de composants de l'inventaire. L'option peut être activée ou désactivée à tout moment sans corrompre la sauvegarde du jeu.

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
   (`user://savegame.json`). La version actuelle du format est **2** ; les
   sauvegardes de version 1 restent acceptées et les champs ajoutés sont chargés
   avec des valeurs par défaut lorsqu'ils sont absents.

---

## État de stabilité et vérifications

Les correctifs récents portent notamment sur les contrôles du bateau, sa
persistance, la récolte permanente des carcasses, les délais de repousse,
l'annulation des fabrications en mode créatif et la validation de l'empreinte
des bâtiments. Ils ont été poussés sur la branche
[`feature/gameplay-final`](https://github.com/WinnyKing57/castaway-bay/tree/feature/gameplay-final).

Avant une fusion vers `main`, effectuer au minimum les vérifications suivantes
dans Godot 4.7 :

1. Lancer `./run.sh --test` et vérifier le résultat `SMOKE_TEST OK`.
2. Récolter une carcasse, sauvegarder, recharger et vérifier qu'elle reste épuisée.
3. Planter une culture, attendre sa maturité, sauvegarder/recharger puis récolter.
4. Déplacer le bateau, consommer du carburant, sauvegarder/recharger et vérifier
   sa position, son orientation et son niveau de carburant.
5. Annuler une fabrication chronométrée en mode normal puis en mode créatif ;
   vérifier qu'aucune ressource n'est créée ou perdue.
6. Tester le placement et le rechargement de bâtiments de plusieurs tailles,
   niveaux et orientations.

Aucun statut CI n'est actuellement publié pour cette branche. Les tests manuels
ci-dessus restent donc nécessaires.

---

## Feuille de route

| Jalon | Contenu | État |
|---|---|---|
| M0 | Socle : projet, île, joueur, récolte, inventaire, sauvegarde | ✅ |
| M1 | Eau/nage, grottes, plusieurs biomes, ambiance sonore | 🟡 |
| M2 | Survie complète : faim, soif, mort/respawn, consommation | ✅ |
| M3 | Artisanat : interface, recettes, outils | ✅ |
| M4 | Construction : grille, fondations, murs, feu de camp, fantôme, niveaux | ✅ |
| M5 | Véhicules : bateau sur l'eau (réparation, carburant, locomotion) | ✅ |
| M6 | PNJ, quêtes, commerce, réputation | ⬜ |
| M7 | Finition : réglages son/souris/vidéo/cheat, export autonome Linux validé | ✅ |

Le détail des idées non planifiées est dans [`IDEAS.md`](IDEAS.md).

Légende : ✅ terminé · 🟡 partiel · ⬜ à faire

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

**État de validation :** la dernière passe de stabilisation a fait l'objet d'une
revue statique des scripts et des changements GitHub. Le lancement de Godot et
l'exécution de `./run.sh --test` doivent être refaits dans un environnement
disposant de Godot 4.7 avant de considérer cette révision comme validée en
exécution. Ne pas interpréter les résultats de tests antérieurs comme une
validation automatique de chaque changement récent.

---

## Crédits et licence

- Code et design : à toi.
- Assets à venir : privilégier le **CC0** (Kenney, Quaternius, Poly Haven,
  ambientCG, Freesound) pour rester libre de toute redistribution.
- Ne pas réutiliser les assets, textes ou fichiers d'un jeu commercial.
