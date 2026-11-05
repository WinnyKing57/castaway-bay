# Castaway Bay — Prochaines étapes

## Fait (M0 → M4 + M5/M7 partiels + stabilisation + persistance)
- [x] Île procédurale, eau low-poly animée, cycle jour/nuit dynamique
- [x] Joueur FPS, récolte (bois, pierre, fibres, baies, métal, argile, graines),
      survie (santé, faim, soif, fatigue), mort et respawn
- [x] Artisanat complet (**C**), recettes avancées (planches, cordes, briques
      cuites, électronique, carburant), outils (hache en pierre doublant le bois)
- [x] Construction modulaire (**B**) : règles d'ancrage, gestion des étages
      (**PgUp / PgDn**), support vertical, alignement fantôme et verrouillage
      d'altitude (**V**), `grid_size` 2 x 2 (tente, lit)
- [x] Menu principal, menu pause, panneau de réglages (volume, sensibilité
      souris, plein écran) et option de triche / mode créatif (matériaux infinis)
- [x] Nage, caméra sous-marine, sons synthétisés à la volée (aucun asset audio)
- [x] Agriculture : semis manuel (graines), sol meuble au repos, croissance visuelle (teinte rouge à
      maturité), récolte pérenne (+2 récoltes, +1 graine)
- [x] Sauvegarde et chargement (**F9** / **F10**) + sauvegarde automatique
      (toutes les 2 min, sortie vers le menu, fermeture de fenêtre, perte de
      focus), format JSON **v2** (v1 acceptée), copie de secours `.bak`
- [x] Persistance complète : joueur (position, cap, regard, à bord), jauges,
      inventaire, barre rapide, horloge et graine, fabrication chronométrée,
      constructions et stations, ressources épuisées + repousse, cultures,
      bateau (position, cap, carburant)
- [x] Bateau : gouvernail (rotation) et propulsion distincts, spawn côtier
      dans l'eau, monter/descendre avec libération propre, réparation (1 métal),
      carburant (réservoir 30, bidon), navigation et sauvegarde de l'état
- [x] Coffres de stockage : interaction (E), interface complète (dépôt/retrait 1 ou tout),
      persistance du contenu dans les sauvegardes v2
- [x] Stabilisation avancée : clés de bord canoniques (anti-doublon partagé mur/porte/fenêtre),
      alignement fantôme d'arêtes, prise en compte directe du mode créatif (matériaux infinis)
      dans les fabrications et constructions
- [x] Portes animées (pivot + battant + rainures), escaliers 4 → 5 marches, lit fonctionnel
- [x] Démolition (clic droit) avec remboursement 75 % des matériaux
- [x] Compatibilité v1 testée et validée sans régression
- [x] CI GitHub Actions : exécution automatique de `./run.sh --test` en headless
- [x] Tests de non-régression : `./run.sh --test` → `SMOKE_TEST OK`
- [x] Export autonome Linux x86_64 en place et testé en mode headless
- [x] **Bugfix** : retour en jeu après les paramètres (le menu ne réapparaissait plus)

## Fait — améliorations construction (batch 1)
- [x] **Fenêtres fonctionnelles et transparentes** : vitrage `TRANSPARENCY_ALPHA` (alpha 0.22,
      roughness 0, metallic 0.2, culling double face), montants en croix, bandes de remplissage
      mur haut et bas, interaction **E** ouvrir/fermer (pivot 90°), état persisté dans la sauvegarde
- [x] **Toits modulaires** : toit plat avec bardeaux en quinconce positionné à y=2.46 (flush
      avec le sommet des murs 2.4 m), toit en pente simple (`roof_slope`) avec tuiles inclinées,
      faîtage à deux pans (`roof_ridge`) avec solin ; 3 fichiers `.tres` ajoutés
- [x] **Escaliers corrigés** : 5 marches (sommet à exactement 1.0 m = 5 × LEVEL_STEP), collision
      en rampe à 22° (au lieu de 45°), marches bicolores (claires/foncées), rambardes fines
- [x] **Matériaux** : cache statique partagé (1 instance par couleur hexadécimale), murs avec
      5 planches en micro-variation de teinte + 2 poutres horizontales (mi-hauteur et sommet),
      fondations sans z-fighting (planches décoratives à +0.21 m)
- [x] **Coffre** : ferrures métalliques aux 4 coins avant, 2 bandes cerclant le coffre, serrure
      centrale, lames de bois sur le corps et le couvercle
- [x] **Demi-mur** (`half_wall`, 1.2 m de hauteur) : nouveau type pour rebords, balustrades
      et allèges de fenêtre ; fichier `.tres` ajouté
- [x] Persistance fenêtres : `is_open` sauvegardé et restauré comme les portes
- [x] Tests de non-régression étendus : fenêtre (toggle + persistance), demi-mur, toit pente,
      faîtage → `SMOKE_TEST OK`

## Fait — améliorations construction (batch 3)
- [x] **Coins de toit** (`roof_corner_out` coin saillant, `roof_corner_in` coin rentrant) :
      deux nouveaux types `Buildable` avec géométrie PrismMesh et fichiers `.tres` ;
      le snap vers la fondation porteuse fonctionne pour eux comme pour les autres toits
- [x] **Ctrl+Z** : annulation de la dernière pose en mode construction (pile `_undo_stack`,
      limite 20 entrées, remboursement intégral, suppression des poutres d'angle liées) ;
      action `undo_build` mappée sur `Ctrl+Z` dans `project.godot` ; mention dans le HUD
- [x] **Poutres d'angle automatiques** : quand deux murs (ou demi-murs) perpendiculaires
      se rejoignent à un coin, une poutre 0.16 × height × 0.16 est spawné automatiquement ;
      retirée quand l'un des deux murs est démoli ou annulé (`Ctrl+Z`) ; reconstruite au
      chargement d'une sauvegarde (`_rebuild_all_corner_beams`)
- [x] **Snap escaliers** (`_snap_stairs_base_y`) : les escaliers se magnétisent sur la
      fondation voisine la plus proche dans un rayon de 2 cases
- [x] Tests de non-régression : coins de toit, undo, poutres d'angle → `SMOKE_TEST OK`
- [x] **Snap vertical intelligent par kind** : `_compute_ghost_y` utilise désormais une logique
      propre à chaque type d'élément au lieu d'utiliser le `hit_y` brut du raycast :
  - **Fondations** : magnétisme sur la fondation voisine la plus proche (comportement inchangé,
    mais `best_diff` initialisé à `INF` pour corriger le bug de valeur initiale)
  - **Toits** (plat, pente, faîtage) : `_snap_roof_base_y()` cherche la fondation porteuse dans
    la case ou les cases voisines immédiates et retourne son Y — le nœud toit est donc posé à la
    même hauteur que la fondation, et son offset interne de 2.46 m le place automatiquement
    au-dessus des murs ; si aucune fondation n'est trouvée, arrondi à LEVEL_STEP
  - **Tous les autres éléments** : `hit_y` arrondi au multiple de LEVEL_STEP le plus proche
    — un mur visant une fondation (hit_y=0.21) snap à 0.2 m, un mur visant un autre mur
    (hit_y=2.6) snap à 2.6 m
- [x] **Offsets internes des toits unifiés** via les constantes `WALL_H = 2.4` et
      `ROOF_Y = WALL_H + 0.06 = 2.46` dans `buildable.gd` ; `ROOF_INTERNAL_OFFSET = 2.46`
      dans `construction.gd` pour maintenir la cohérence
- [x] **Bug `_aligned_neighbor_y` corrigé** : `best_diff` initialisé à `INF` (était `0.0`),
      la fondation la plus proche était parfois ignorée

## Fait — améliorations construction (batch 4)
- [x] **Détection d'assemblage** : halo vert-cyan sur le fantôme quand un toit est posé
      contre un autre toit compatible (même niveau, voisinage 1 case) — `_can_assemble_roof`
      + `_set_ghost_assembly_visual` sur `Buildable`
- [x] **Escalier 2 cases de large** (`grid_size = 2`) : `stairs.tres` passe à 2 × 2 et
      `_build_stairs` agrandit marches/limons/rambarde/ramp pour la largeur 1.84 m
- [x] **Aperçu des dimensions** : le HUD de construction affiche la taille (ex. `2x2`, `1×1 [bord]`)

## À faire — corrections prioritaires (bugs actifs)
- [ ] **Validation manuelle** (Godot avec fenêtre) : session de jeu manuelle avec rendu graphique
      complet (transparence du vitrage, bardeaux, collision escaliers, fluidité navigation bateau)

## À faire — améliorations construction (suite)
_(tous les items du batch 4 sont faits — voir « Fait — améliorations construction (batch 4) »)_

## À faire — interface de construction
_(dimensions et indicateur d'assemblage traités au batch 4 — voir « Fait — améliorations construction (batch 4) »)_

## Idées issues des repos de référence
(Sources d'inspiration : `tomlooman/ActionRoguelike`, `tomlooman/EpicSurvivalGame` — voir `docs/INSPIRATION.md`)

### Gameplay / systèmes gameplay
- ActionRoguelike : architecture de systèmes d'actions paramétrables (input action → effets),
      feedback de damage (dégâts popups), significance manager / streaming monde,
      save roguelike par événements — à adapter en GDScript (InputMap, signals, autoloads)
- EpicSurvivalGame : composant inventaire persistant (pickup/weapon/flashlight),
      gestion faim/soif/health avec timers et seuils critiques,
      durability des armes — à transposer vers notre `GameState`/hotbar

### Construction / habitation
- EpicSurvivalGame : kits de maisons (House_Basic_01_SM, portes Basic, fenêtres Basic,
      murs/coins) — à s'inspirer pour des maisons pré-faits / kits modulaires plus riches
      que les bâtis primitifs en code (bardeaux, toits, fondations)
- ActionRoguelike : patterns de construction modulaire / placement — déjà alignés avec notre
      grille 1m ; noter les patterns de snap/rotation

### Visuel / graphisme
- EpicSurvivalGame : kits de maisons, matériaux (murs, sols, toits), éclairage — pistes de
      matcaps/low-poly plus riches (poutres visibles, bardeaux)
- ActionRoguelike : effets visuels d'action (dash, blackhole, projectile) — pistes de VFX
      procéduraux pour feux, éclats, dégâts

### Technique
- ActionRoguelike : significance / streaming — pistes pour le monde (islands, biomes)
- EpicSurvivalGame : persistence inventory — pistes pour sauvegarde plus riche

---

## À faire (par ordre de priorité)

### 1. Grottes et biomes souterrains (M1 suite)
- [x] Génération de cavités / entrées de grottes procédurales sur les flancs rocheux —
      `world/island.gd` : `_generate_caves()` place des arches de roche sombres sur les hauteurs,
      au moins une grotte garantie par île
- [x] Ambiance d'éclairage sombre nécessitant la torche — `cave_darkness` dans `world/day_night.gd`,
      piloté par `main.gd` (assombrit lumière ambiante, brouillard et ciel)
- [x] Minerais spécifiques et rares dans les profondeurs (métaux précieux, charbon, cristaux) —
      kinds `cristal`, `fer`, `charbon`, `or` + `data/items/coal.tres`, `gold.tres` ; 2 charbon
      et 2 or garantis sur les sommets, tirage supplémentaire au-dessus de 14 m
- [x] Ambiance sonore réverbérante et gouttes d'eau pour les intérieurs — `_make_cave()` enrichi
      (souffle + gouttes), joué périodiquement dans les grottes ; piste musicale `cave` dédiée

### 2. Agriculture et élevage avancés
- [ ] Système d'arrosage (récipient d'eau douce / pluie)
- [ ] Plusieurs variétés de cultures (maïs, blé, herbes médicinales)
- [ ] Pièges à petits gibiers pour des sources renouvelables de viande et peaux
- [ ] Compostage des fibres et débris végétaux

### 3. PNJ, campements et commerce insulaire (M6)
- [ ] Épave de navire marchand avec survivants ou automate de troc
- [ ] Système de réputation et quêtes d'approvisionnement (bois, minerai, denrées)
- [ ] Monnaie locale ou troc direct d'objets rares
- [ ] Dialogues et livre de bord / journal d'aventure

### 4. Véhicules et exploration lointaine (M5 suite)
- [x] Véhicule terrestre (buggy / quad tout-terrain pour parcourir les reliefs) : `world/quad.gd` (CharacterBody3D, pilotage, emboard/exit, sauvegarde) + spawn/island/save + interaction E
- [ ] Îlots secondaires accessibles en bateau avec ressources uniques
- [x] Cartographie / boussole artisanale — boussole HUD 8 directions (`ui/hud.gd`) suivant le cap du joueur

### 5. Finition et distribution (M7 suite)
- [x] Intégration de musiques d'ambiance dynamiques — pistes `day`/`dusk`/`night`/`cave`
      bouclées, transitions automatiques (`autoload/sfx.gd`, `set_cave()`)
- [ ] Page de distribution itch.io, packaging et builds multi-plateformes

---

## Fait — carte étendue et biomes (monde actuel)
- [x] Île agrandie (260 → 420 m, grille 160) : monde plus vaste, même résolution de détail
- [x] Biomes de surface garantis sur chaque île par secteurs angulaires déformés par un
      bruit basse fréquence : **forêt dense**, **plaines plates**, **bocage**,
      **hauteurs rocheuses**, plus **plage** littorale et **zone agricole** dédiée
- [x] Relief modelé par biome : plaines aplaties, hauteurs accentuées, plateau agricole
      avec fondu progressif (aucune falaise aux transitions de biome)
- [x] Végétation par biome : bosquets d'arbres serrés en forêt (vraie densité de
      sous-bois), palmiers/argile/rochers sur la plage, buissons/graines en plaine,
      minerais en altitude ; cultures semées dans la ferme
- [x] Couleurs de terrain distinctes : sable, plaine claire, forêt sombre, bocage,
      roche et sol agricole
- [x] Spawn côtier du bateau et zone de nage recalculés pour la nouvelle taille
- [x] Smoke test étendu : présence de tous les biomes, cultures et point d'échouage
      valide → `SMOKE_TEST OK`

---

## Feuille de route — toutes les prochaines étapes (développement complet)

> TODO volontairement exhaustif : chaque lot à implémenter doit finir par des tests
> de non-régression (`./run.sh --test` → `SMOKE_TEST OK`) et, quand le lot le permet,
> des tests headless ciblés.

### A. Grottes et biomes souterrains (M1 suite) — livré
- [x] Minerais spécifiques et rares dans les profondeurs (cristal, fer, charbon, or) —
      `world/harvestable.gd`, `data/items/{crystal,coal,gold}.tres`
- [x] Éclairage sombre nécessitant la torche — constructible `torch` + `OmniLight` (`world/buildable.gd`, `data/buildables/torch.tres`)
- [x] Ambiance sonore grottes — stream `cave` enrichi (souffle + gouttes) (`autoload/sfx.gd`)
- [x] Génération de cavités / entrées de grottes procédurales sur les flancs rocheux —
      arches de roche sombres, une grotte minimum garantie (`world/island.gd`)
- [x] Ambiance d'éclairage sombre (profondeur, portée de la torche) — `cave_darkness`
      progressif (`world/day_night.gd`, piloté par `main.gd`)
- [x] Ambiance sonore réverbérante et gouttes d'eau pour les intérieurs — `_make_cave()` +
      piste `cave` (`autoload/sfx.gd`, `Sfx.set_cave()`)

### B. PNJ, campements et commerce insulaire (M6)
- [x] Automate de troc (marchand itinérant) — `world/trader.gd`, spawn/save island
- [ ] Épave de navire marchand avec survivants
- [ ] Système de réputation et quêtes d'approvisionnement (bois, minerai, denrées)
- [ ] Monnaie locale ou troc direct d'objets rares
- [ ] Dialogues et livre de bord / journal d'aventure

### C. Véhicules et exploration lointaine (M5 suite)
- [x] Véhicule terrestre (buggy) — `world/quad.gd`
- [ ] Îlots secondaires accessibles en bateau avec ressources uniques
- [x] Cartographie / boussole artisanale — boussole HUD 8 directions

### D. Finition et distribution (M7)
- [x] Intégration de musiques d'ambiance dynamiques (réelles) + transitions — pistes bouclées
      `day`/`dusk`/`night`/`cave` (`autoload/sfx.gd`)
- [ ] Page de distribution itch.io, packaging et builds multi-plateformes

### E. Gameplay et survie complémentaire
- [ ] Système d'arrosage, variétés de cultures, pièges, compostage (agriculture)
- [ ] Pêche à la ligne, noyade/apnée, naufrage, tempêtes
- [ ] Élevage, durabilité des outils, sommeil (lit)

### F. Technique et architecture
- [ ] Streaming des zones, LOD, MultiMesh, mode manette, Steam Deck, traductions
- [x] Tests headless ciblés : cave, minerais profonds (charbon/or), streams audio (dont
      `cave`/`music`) ajoutés au smoke test ; reste : torche, trader, carte

## Prochaines étapes prioritaires (feuille de route)

1. **Grotte complète** (cavités + torche + ambiance) — lot A : **fait**.
2. **PNJ/commerce complet** (réputation/quêtes/dialogues) — lot B.
3. **Îlots secondaires** (M5) — lot C : **hors périmètre pour l'instant** (monde actuel uniquement ;
   la cartographie/boussole est faite ; biomes, plages, forêts et zone agricole du monde actuel
   sont livrés).
4. **Finition M7** — lot D (musiques faites ; reste la distribution/itch.io).
5. **Gameplay complémentaire** — lot E.
6. **Technique/LOD/manette/traductions** — lot F.
