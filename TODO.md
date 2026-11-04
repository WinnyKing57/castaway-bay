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
- [x] Portes animées (pivot + battant), escaliers 4 marches, lit fonctionnel
- [x] Démolition (clic droit) avec remboursement 75 % des matériaux
- [x] Compatibilité v1 testée et validée sans régression
- [x] CI GitHub Actions : exécution automatique de `./run.sh --test` en headless
- [x] Tests de non-régression : `./run.sh --test` → `SMOKE_TEST OK`
- [x] Export autonome Linux x86_64 en place et testé en mode headless
- [x] **Bugfix** : retour en jeu après les paramètres (le menu ne réapparaissait pas)

## À faire — corrections prioritaires (bugs actifs)

- [ ] **Validation manuelle** (Godot avec fenêtre) : session de jeu manuelle avec rendu graphique
      complet (ambiance météo, fluidité de navigation du bateau en conditions réelles)

## À faire — améliorations construction (priorité haute)

### Fenêtres fonctionnelles et transparentes
- [ ] Remplacer le `PlaneMesh` opaque par un vrai matériau transparent (vitrage) :
      `StandardMaterial3D` avec `transparency = TRANSPARENCY_ALPHA`, `albedo_color` bleu-clair
      alpha 0.25, `roughness = 0.0`, `metallic = 0.2` pour l'effet verre
- [ ] Ajouter des montants de fenêtre en croix (4 barres fines `BoxMesh` 0.04 × 0.04 × épaisseur)
      pour structurer le panneau de verre et donner un aspect plus réaliste
- [ ] La fenêtre doit comporter un encadrement de mur de part et d'autre pour combler le vide
      au-dessus et en dessous (deux bandes 1.0 × 0.65 × 0.16 à y≈0.6 et y≈1.85)
- [ ] Interaction (E) : ouvrir/fermer la fenêtre (pivote le panneau de verre de 90° comme la porte)
      avec persistance de l'état dans la sauvegarde

### Toits modulaires et assemblage
- [ ] Remplacer le toit actuel (planche plate + prisme décoratif isolé) par des pièces
      modulaires distinctes permettant de couvrir des surfaces rectangulaires :
  - **Toit plat** : dalle 1.0 × 0.1 × 1.0 à l'étage supérieur (version actuelle simplifiée)
  - **Toit pente simple** (une face) : prisme 1.0 × 0.6 × 1.0 incliné selon la rotation, pour les
    toits sur une seule pente (appentis, auvent)
  - **Toit en V** / arête de faîtage : élément d'arête central combinant deux pentes se rejoignant
    en angle pour fermer un toit à deux pans
  - **Toit coin intérieur** / **coin extérieur** : pièces de raccord pour les angles à 90°
- [ ] Ajuster le positionnement : les toits doivent reposer sur les murs sans débord excessif,
      aligner automatiquement leur y sur le sommet des murs voisins (LEVEL_STEP × 12 ≈ 2.4 m)
- [ ] Ajouter une détection d'assemblage : un toit posé à côté d'un autre toit de même type/rotation
      doit générer un bord de raccord invisible (ajuster la collision pour éviter les espaces)

### Escaliers — positionnement et intégration
- [ ] Corriger l'alignement vertical : le sommet de l'escalier (marche haute) doit arriver exactement
      au niveau du sol de l'étage supérieur (y = nb_niveaux × LEVEL_STEP, soit 1.0 m pour 5 fondations)
- [ ] La collision en pente (inclinée à −45°) est trop raide ; réduire l'angle à ~20–25° et la
      centrer mieux pour permettre une montée fluide sans sauter par-dessus les marches
- [ ] Ajouter un mode de snap automatique : en mode construction, proposer l'altitude cible de la
      fondation supérieure voisine lorsque le joueur place un escalier à côté d'un étage existant
- [ ] Permettre les escaliers à 2 cases de large (`grid_size = 2`) pour les constructions plus grandes

### Matériaux et rendu des éléments constructibles
- [ ] Mettre en cache les matériaux communs (une instance partagée par couleur) pour économiser la
      mémoire GPU : actuellement chaque `_make_material()` crée une nouvelle ressource indépendante
- [ ] Murs : ajouter une légère variation de teinte entre les planches (micro-variation ±5 % de
      luminosité) ou une texture procédurale (bruit UV) pour casser l'aspect monochrome
- [ ] Murs : ajouter la poutre verticale aux angles (montants) pour renforcer l'aspect charpente
      quand deux murs perpendiculaires sont posés l'un à côté de l'autre
- [ ] Fondations : rendre la planche décorative (les 3 lames) légèrement en relief (z offset +0.01)
      plutôt qu'enfouies dans la surface — évite le z-fighting visible
- [ ] Escaliers : utiliser deux teintes de bois (marches claires, limons foncés) pour mieux séparer
      visuellement la structure portante des surfaces de marche
- [ ] Toits : ajouter un matériau tuile/bardeaux via la répétition de `BoxMesh` plats en quinconce
      sur la surface (3 rangées × 4 tuiles) pour donner un aspect couverture réaliste
- [ ] Coffre : ajouter des ferrures métalliques aux angles (8 petits cubes sombres) et les deux
      bandes en métal qui cerclent le couvercle pour renforcer le visuel

### Alignement et cohérence des éléments entre eux
- [ ] Fenêtre : la fenêtre actuelle est trop courte (0.7 m) et ne s'encadre pas bien dans un mur
      2.4 m — prévoir une version haute (0.8 × 1.2 × 0.16) centrée entre y=0.8 et y=2.0,
      avec bandes de remplissage haut et bas comme le mur standard
- [ ] Sol et escalier : quand un escalier est posé contre une fondation d'étage, le joueur doit
      pouvoir monter sans "sauter" d'un coup — tester et ajuster la collision en rampe avec un
      `CapsuleShape3D` de test pour valider la fluidité
- [ ] Mur + porte + fenêtre : uniformiser l'épaisseur (0.16 m) et la hauteur (2.4 m) pour que les
      éléments de bord soient flush avec les murs voisins sans espace ni dépassement
- [ ] Toit + mur : le toit actuel est positionné à y=2.3 mais le sommet du mur est à y=2.4 → le toit
      dépasse légèrement ou chevauche. Ajuster le niveau cible du toit à y=2.4 + épaisseur
- [ ] Ajouter un élément "demi-mur" (hauteur 1.2 m) pour les rebords, balustrades et allèges de
      fenêtre sans devoir construire un mur complet

## À faire — interface de construction
- [ ] Afficher un aperçu des dimensions de l'élément sélectionné dans le HUD (largeur × profondeur)
- [ ] Indicateur visuel quand le toit peut s'assembler avec un toit voisin (contour de liaison en vert)
- [ ] Annuler la dernière pose (Ctrl+Z) sans repasser en mode démolition

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
