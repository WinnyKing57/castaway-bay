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

## Fait — améliorations construction (batch 2 — ergonomie placement)
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

## À faire — corrections prioritaires (bugs actifs)
- [ ] **Validation manuelle** (Godot avec fenêtre) : session de jeu manuelle avec rendu graphique
      complet (transparence du vitrage, bardeaux, collision escaliers, fluidité navigation bateau)

## À faire — améliorations construction (suite)
- [ ] Coins de toit (intérieur et extérieur) : pièces de raccord 45° pour les angles
- [ ] Détection d'assemblage : indicateur visuel (contour vert sur l'arête) quand un toit
      est posé contre un autre toit compatible

### Escaliers
- [ ] Snap automatique vers l'étage voisin quand le joueur place un escalier près d'un étage
- [ ] Escalier 2 cases de large (`grid_size = 2`) pour les constructions plus grandes

### Murs et construction
- [ ] Poutres verticales aux angles : quand deux murs sont posés perpendiculairement, afficher
      un montant 0.15 × 2.4 × 0.15 à l'intersection pour renforcer l'aspect charpente
- [ ] Annuler la dernière pose (**Ctrl+Z**) sans repasser en mode démolition

## À faire — interface de construction
- [ ] Afficher un aperçu des dimensions de l'élément sélectionné dans le HUD (largeur × profondeur)
- [ ] Indicateur visuel quand le toit peut s'assembler avec un toit voisin (contour de liaison en vert)

## À faire (par ordre de priorité)

### 1. Grottes et biomes souterrains (M1 suite)
- [ ] Génération de cavités / entrées de grottes procédurales sur les flancs rocheux
- [ ] Ambiance d'éclairage sombre nécessitant la torche
- [ ] Minerais spécifiques et rares dans les profondeurs (métaux précieux, charbon, cristaux)
- [ ] Ambiance sonore réverbérante et gouttes d'eau pour les intérieurs

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
- [ ] Véhicule terrestre (buggy / quad tout-terrain pour parcourir les reliefs)
- [ ] Îlots secondaires accessibles en bateau avec ressources uniques
- [ ] Cartographie / boussole artisanale

### 5. Finition et distribution (M7 suite)
- [ ] Intégration de musiques d'ambiance dynamiques
- [ ] Page de distribution itch.io, packaging et builds multi-plateformes
