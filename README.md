# Castaway Bay

Jeu de survie / construction sur une île déserte, développé avec **Godot 4.7**.
Remake libre et original, inspiré des jeux de survie insulaire (aucun asset
ni code d'un jeu commercial n'est utilisé).

> État actuel : **M0 terminé** — socle technique jouable (île procédurale,
> océan, cycle jour/nuit, joueur FPS, récolte, inventaire, sauvegarde).

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
| F9 | sauvegarder |
| F10 | charger |
| Échap | libérer / capturer la souris |

---

## Structure du projet

```
autoload/        singletons globaux (état, base de données, sauvegarde, audio)
data/            définitions de données : ItemData, RecipeData + .tres
player/          contrôleur joueur (scène + script)
world/           île procédurale, ressources récoltables, océan, jour/nuit
ui/              HUD
main.tscn/.gd    assemblage de la scène de jeu
```

### Les 4 règles d'architecture

1. **Data-driven** : un objet ou une recette = un fichier `.tres` dans
   `data/items/` ou `data/recipes/`. Aucun code à écrire pour en ajouter.
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
| M1 | Eau/nage, grottes, plusieurs biomes, ambiance sonore | ⬜ |
| M2 | Survie complète : cuisson, eau potable, repos, mort/respawn | ⬜ |
| M3 | Artisanat : interface, établis, déblocages par niveau | ⬜ |
| M4 | Construction : grille, murs, toits, portes, placement fantôme | ⬜ |
| M5 | Véhicules : bateau et voiture (physique simple) | ⬜ |
| M6 | PNJ, quêtes, commerce, réputation | ⬜ |
| M7 | Finition : menus, réglages, audio, export Linux + page itch.io | ⬜ |

Le détail des idées non planifiées est dans [`IDEAS.md`](IDEAS.md).

---

## Exporter pour Linux

1. Éditeur → **Éditeur ▸ Gérer les modèles d'exportation** → télécharger.
2. **Projet ▸ Exporter… ▸ Linux** (preset déjà configuré).
3. Sortie : `build/linux/castaway-bay.x86_64`.

Le binaire produit est autonome (PCK intégré), testable sur toute
distribution Linux x86_64 récente.

---

## Crédits et licence

- Code et design : à toi.
- Assets à venir : privilégier le **CC0** (Kenney, Quaternius, Poly Haven,
  ambientCG, Freesound) pour rester libre de toute redistribution.
- Ne pas réutiliser les assets, textes ou fichiers d'un jeu commercial.
