# Castaway Bay — Prochaines étapes

## Fait (M0 → M5 + M7 complet + correctifs bloquants)
- [x] Île procédurale, eau low-poly animée, cycle jour/nuit dynamique
- [x] Joueur FPS, récolte, survie (santé, faim, soif, fatigue), mort et respawn
- [x] Artisanat complet (**C**), recettes avancées, outils (hache en pierre doublant le bois)
- [x] Système de construction modulaire (**B**) : règles d'ancrage, gestion des étages, support vertical, alignement fantôme et verrouillage d'altitude (**V**)
- [x] Menu principal, menu pause, panneau de réglages (volume, sensibilité souris, plein écran) et option de triche / mode créatif
- [x] Nage, caméra sous-marine, sons synthétisés à la volée (aucun asset externe requis)
- [x] Éléments construits, matériaux avancés (planches, briques cuites, cordes, électronique, carburant)
- [x] Agriculture avancée : cycle visuel de pousse (changement de teinte à maturité), boucle de semis et récolte pérenne (+2 récoltes, +1 graine)
- [x] Sauvegarde et chargement robustes (**F9** / **F10**), persistance de la graine, inventaire, bâtiments et repousse des ressources du monde
- [x] Véhicule marin : bateau sur l'eau (`Boat`), réparation avec métal (`repair()`), consommation de carburant et navigation
- [x] Correctif bloquant `Boat.repair(player)` et validation totale via `./run.sh --test` (0 erreur, SMOKE_TEST OK)
- [x] Export autonome Linux x86_64 (`build/linux/castaway-bay.x86_64`) opérationnel et testé en mode headless

## Prochaines étapes de développement (Roadmap vers un jeu complet)

### 1. Grottes et biomes souterrains (M1 suite)
- [ ] Génération de cavités / entrées de grottes procédurales sur les flancs rocheux
- [ ] Ambiance d'éclairage sombre nécessitant la torche
- [ ] Minerais spécifiques et rares dans les profondeurs (veines de métaux précieux, charbon, cristaux)
- [ ] Ambiance sonore réverbérante et gouttes d'eau pour les intérieurs

### 2. Agriculture et élevage avancés
- [ ] Système d'arrosage (récipient d'eau douce / pluie)
- [ ] Plusieurs variétés de cultures (maïs, blé, herbes médicinales)
- [ ] Pièges à petits gibiers pour sources renouvelables de viande et peaux
- [ ] Compostage des fibres et débris végétaux

### 3. PNJ, campements et commerce insulaire (M6)
- [ ] Épave de navire marchand avec survivants ou automate de troc
- [ ] Système de réputation et quêtes d'approvisionnement (bois, minerai, denrées)
- [ ] Monnaie locale ou troc direct d'objets rares
- [ ] Dialogues et livre de bord / journal d'aventure

### 4. Véhicules et exploration lointaine (M5 suite)
- [ ] Véhicule terrestre (buggy / quad tout-terrain pour parcourir les reliefs)
- [ ] Îlots secondaires accessibles en bateau avec ressources uniques
- [ ] Cartographie / boussole artisanale

### 5. Finition et distribution
- [ ] Intégration de musiques d'ambiance dynamiques
- [ ] Page de distribution itch.io, packaging et builds multi-plateformes
