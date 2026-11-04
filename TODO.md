# Castaway Bay — Prochaines étapes

## Fait (M0 → M4 + M1 partiel + maison + réglages)
- [x] Île procédurale, eau, jour/nuit
- [x] Joueur FPS, récolte, survie, mort/respawn
- [x] Artisanat (C), construction (B), sauvegarde (F9/F10)
- [x] Menu principal / pause / réglages
- [x] Nage, sons synthétisés, export templates
- [x] Maison, matériaux (plank/brick/rope), ferme (seed), nouveaux buildables
- [x] Tests finaux : `./run.sh --test` propre (0 erreur, SMOKE_TEST OK)
- [x] Véhicule : bateau sur l'eau (spawn + enter/exit, `Boat`)
- [x] Passe de stabilisation : inventaire, occupation inter-catégories, validation des sauvegardes, bateau/joueur, `kind` des données, tests de non-régression (voir README « Stabilité et robustesse »)

- [x] Persistance complète (joueur, bateau, ressources, cultures, fabrication, autosave, `.bak`), stations multiples, `grid_size`, artisanat chronométré

## À faire (par ordre de priorité)
- [ ] **CI** : exécuter `./run.sh --test` (Godot 4.7 headless) sur chaque PR
- [ ] **Coffres** : contenu stockable (puis sauvegardé)
- [ ] **Validation manuelle** (Godot avec fenêtre) : monter/descendre du bateau, mourir à bord, charger en navigation, poser mur/porte/fenêtre sur un même bord
- [ ] **Finition M7** : réglages son, menus avancés, export Linux `x86_64` (binaire exporté en place)
- [ ] **Grottes / biomes** (M1 suite) : nouvelle zone avec loots spécifiques (éclairage torche déjà dispo)
- [ ] **Farming avancé** : semis manuels, croissance visuelle
- [ ] **PNJ / commerce / réputation** (M6)
- [ ] **Finition page / distribution** : itch.io, build autonome
