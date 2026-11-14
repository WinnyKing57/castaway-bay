# Castaway Bay — Journal des décisions

> Ce document trace les décisions techniques prises en cours de route, avec leur
> contexte et les alternatives écartées. Il évite de « re-débattre » un choix
> déjà tranché et explique les compromis visibles dans le code.

## Format

Une entrée = un titre, la décision, le pourquoi, et ce qui a été écarté.

---

## Phase 1 — Modèle de données, icônes, sauvegarde v3

### Valeurs d'énumération sans accents

**Décision** : les valeurs stockées dans les `.tres` et comparées en code
restent en ASCII (`carre`, `buche`, `materiel`, `electricite`, `materiels`,
`energie`, `defense`, `exterieur`). Seuls les libellés affichés sont accentués.

**Pourquoi** : ces chaînes sont sérialisées dans les ressources et comparées
dans les scripts ; l'ASCII évite tout risque d'encodage et de casse dans les
`.tres`, les sauvegardes et les identifiants.

### Champs ajoutés avec valeurs par défaut

**Décision** : chaque nouveau champ (`tags`, `rarity`, `icon_color`,
`icon_shape`, `weight`, `category`, `tier`, `unlocked_by`, `batch_size`,
`upgrade_to`, `health`, `preview_scale`) a une valeur par défaut côté script.

**Pourquoi** : une ressource `.tres` ou une sauvegarde ancienne reste lisible
sans migration bloquante. La migration des fichiers est un nettoyage one-shot,
pas une dépendance d'exécution.

### Icônes procédurales : `Image` plutôt que `SubViewport`

**Décision** : `IconFactory` dessine les icônes pixel par pixel dans une
`Image` 64 × 64 (`set_pixel`), puis crée une `ImageTexture`. Les formes
(cercle, carré, losange, goutte, feuille, lingot, bûche, outil), la couleur et
le liseré de rareté sont dérivés des données de l'objet.

**Pourquoi** : c'est synchrone, sans dépendance GPU et donc **testable en
headless**. Le rendu via `SubViewport` + `Control._draw()` a été implémenté
puis abandonné : en mode headless (`--headless`, renderer dummy)
`SubViewport.get_texture().get_image()` renvoie `null`, ce qui rendait le smoke
test impossible à valider.

**Écarté** : texture importée depuis un asset externe (interdit), génération
via `SubViewport` (non fiable headless), shaders (sur-dimensionné pour 64 px).

### Vignettes de constructibles en 2D procédurale

**Décision** : `get_buildable_icon()` produit une vignette 2D dont la forme
dérive de `kind` et la couleur de `tier`, plutôt qu'un rendu 3D.

**Pourquoi** : même contrainte headless que ci-dessus. Le visuel 3D réel reste
disponible dans le jeu via `Buildable` ; la vignette sert d'aperçu d'interface.
Si un rendu 3D hors-écran devient nécessaire, il sera ajouté derrière la même
API (`get_buildable_icon`), sans changer les appelants.

### Migration des `.tres` par édition textuelle

**Décision** : les champs manquants ont été ajoutés aux fichiers `.tres`
existants par une édition textuelle contrôlée (ajout / remplacement de lignes),
puis validés par le smoke test.

**Pourquoi** : `ResourceSaver.save()` sur des ressources rechargées a réécrit
les fichiers en **supprimant des propriétés existantes** (`max_stack`, `value`,
`grid_size`, `craft_time`…). L'édition textuelle est additive et vérifiable par
`git diff`.

**Écarté** : outil de migration `-s script.gd` + `ResourceSaver` (destructif),
migration à l'exécution uniquement (ne satisfait pas la mise à niveau des
fichiers).

### Cohérence des données vérifiée par le smoke test

**Décision** : le smoke test échoue si une catégorie est vide, si un tag est
vide, ou si une recette référence un ingrédient / une sortie inexistante.

**Pourquoi** : le contenu est data-driven ; une faute de frappe dans un `.tres`
doit casser la CI, pas la partie.

### Sauvegarde v3 avec migration v1 / v2

**Décision** : `SAVE_VERSION` passe à **3**. `SaveSystem._migrate()` complète
les sauvegardes antérieures avec les valeurs par défaut des champs optionnels
(`hotbar_index`, `craft`, `npc`, `world_state`, `world_time`, `world_seed`)
puis les porte à la version courante.

**Pourquoi** : la règle d'architecture impose un format versionné et des
champs nouveaux optionnels. Aucune donnée existante n'est supprimée ; un fichier
plus récent que le jeu reste refusé.

**Testé** : le smoke test écrit de vraies sauvegardes `version: 1` et
`version: 2`, les recharge et vérifie que l'état (inventaire, jauges) est bien
restauré.

### Inventaire : glisser-déposer natif, panneau sans état

**Décision** : le panneau d'inventaire utilise `_get_drag_data` /
`_can_drop_data` / `_drop_data` de Godot et délègue toute écriture à
`GameState.set_hotbar_item()` / `swap_hotbar_items()`.

**Pourquoi** : la règle « UI à l'écoute, GameState central » reste valable, et
le mécanisme natif évite une réimplémentation fragile (drag fantôme, seuils,
annulation). Le test headless appelle la même méthode publique
(`assign_hotbar`) que le dépôt, sans simuler la souris.

**Écarté** : glisser-déposer maison à base de `gui_input` (plus de code pour un
résultat moins accessible), édition directe de `GameState.hotbar_items` depuis
l'interface (casserait les signaux et la sauvegarde).

### Barre rapide : 5 cases fixes, réorganisation par échange

**Décision** : `hotbar_items` reste un tableau de 5 identifiants ; assigner un
objet le place dans la case visée et sélectionne cette case ; deux cases
peuvent être échangées. Une case peut être vidée (`""`).

**Pourquoi** : aucune abstraction de conteneur n'est nécessaire tant que
l'inventaire n'a pas de capacité ni de poids exploité en jeu. Le format de
sauvegarde v3 n'est pas modifié (mêmes champs).

### Progression : XP globale et portes de contenu par niveau

**Décision** : une seule progression globale (`level`, `xp`) alimentée par les
actions existantes (récolte, artisanat, construction, quêtes). Les niveaux ne
donnent pas de points à répartir : ils débloquent des recettes via
`unlocked_by = "level:N"` et restaurent la fatigue.

**Pourquoi** : c'est la plus petite mécanique qui rend la boucle « récolter →
fabriquer → construire » cumulative, sans introduire d'arbre de talents ni de
seconde monnaie. Le rétablissement d'une pose (Ctrl+Y) ne donne pas d'XP pour
éviter le farming.

**Écarté** : compétences séparées par métier (trop de contenu à équilibrer),
bonus permanents aux jauges (les jauges sont bornées à 100 partout).

### Sommeil centralisé dans GameState

**Décision** : le lit appelle `GameState.sleep_until_morning()` ; `hour_of_day()`
et `is_night()` vivent aussi dans GameState (nuit 19 h → 6 h).

**Pourquoi** : l'heure, la fatigue et la vie sont déjà centralisées et
sauvegardées. Le test headless peut ainsi vérifier le sommeil sans instancier de
lit ni simuler une interaction.

### Champ de sauvegarde optionnel sans changement de version

**Décision** : `progression {level, xp}` est ajouté au format v3 en champ
optionnel, avec valeurs par défaut et validation ; `SAVE_VERSION` reste 3.

**Pourquoi** : la règle impose des champs nouveaux optionnels. Un ancien
binaire ignore le bloc ; un nouveau binaire lit les anciennes sauvegardes. Une
montée de version n'apporterait aucune migration supplémentaire.
### Survivant de l'épave (kind = "survivor")

**Décision** : le Trader créé dans `_spawn_trader()` (position 60,0,60) est un marchand
de l'île ; le Trader créé pour le survivant près de l'épave (`_spawn_secondary_islands`,
position wreck + Vector3(0,0.5,0)) reçoit `kind = "survivor"`. Le même mécanisme de
troc et de quêtes s'applique, mais son premier dialogue et sa journalisation diffèrent.

**Pourquoi** : éviter une duplication de logique de dialogue et de journal entre deux instances
identiques de `Trader`. La sauvegarde v3 transmet le champ `kind` via `get_save_state()`
→ `apply_save_state()`.

**Écarté** : donner des comportements physiques différents au survivant (pas fait ici).

### Découpage du code (Phase 7.1)

**Décision** : `main.gd` ne garde que l'assemblage de la scène, les commandes
globales et le branchement du smoke test. Le smoke test (≈ 1 200 lignes) est
extrait dans `tests/smoke_test.gd` (classe `SmokeTest`, mêmes champs que
`main.gd`, branchement par `setup()`).

**Pourquoi** : `main.gd` dépassait 1 700 lignes ; le smoke test est le plus gros
bloc et le plus facile à isoler sans toucher au gameplay. Les autres fichiers
surdimensionnés (`world/buildable.gd`, `world/island.gd`,
`systems/construction.gd`) restent à découper par petits pas, test après chaque
extraction, car ils touchent au rendu (non couvert par le smoke test).

**Écarté** : tout découper d'un coup (risque de régression non couverte par les
tests headless).

### Distribution itch.io et packaging

**Décision** : la distribution se fait par un export Linux x86_64 autonome (PCK
intégré) testé en headless, avec des instructions de packaging et d'upload
itch.io dans `README.md`.

**Pourquoi** : le projet n'a pas d'assets externes ni de dépendances, donc un
seul binaire autonome suffit pour la distribution. Les autres plateformes
(Windows, macOS, Android, iOS) utilisent les presets Godot existants.

**Écarté** : les builds multi-plateformes automatisés (hors périmètre pour
l'instant, lot F).

### Visuels des véhicules (Phase 7 — suite)

**Décision** : les véhicules (bateau / quad) disposent d'un mesh visuel de base
procedural via `Vehicle._build_visual()` ; `Boat` allonge sa coque via
`_visual_length()`.

**Pourquoi** : le socle `Vehicle` créait la capsule de collision mais **aucun
mesh** — les véhicules étaient donc invisibles (bateau / quad jamais vus).

**Écarté** : modèles 3D artistiques dédiés (pas d'assets externes dans le périmètre).

### Orientation des grottes (Phase 7 — suite)

**Décision** : les entrées de grottes (`_build_cave_entrance`) s'ouvrent vers le
bas depuis le sommet du massif (vers -Y local) ; le linteau joue le plafond de la
cavité, les montants descendent.

**Pourquoi** : l'entrée et la cavité étaient orientées vers le haut (vers +Y),
l'entrée ne correspondait pas à une ouverture de grotte dans le massif.

**Écarté** : ouverture sur le flanc extérieur du massif plutôt que sur le sommet.
