# 13 — Inventaire et HUD

Deux vues lisent le même état central (`GameState`) et n'écrivent jamais
l'inventaire directement : elles passent par les méthodes publiques de
`GameState` et écoutent ses signaux.

## 1. Panneau d'inventaire (**I**)

`InventoryPanel` (attaché à `HUD`) est une superposition plein écran, construite
en code au-dessus d'un `PanelContainer` déclaré dans la scène.

| Zone | Contenu |
|---|---|
| En-tête | titre, bouton **Fermer (I)** |
| Recherche | nom, id ou description (insensible à la casse) |
| Onglets | `Tout`, `Ressources`, `Nourriture`, `Matériel`, `Outils`, `Construction`, `Divers` |
| Grille | 6 colonnes de cases 76×76 : icône procédurale (`IconFactory`), quantité, infobulle nom + description |
| Résumé | nombre d'objets affichés et total possédé |
| Barre rapide | 5 cases (une par touche `1`–`5`), sélection et dépôt |

### Glisser-déposer

Le panneau utilise le **système de glisser-déposer natif de Godot**
(`_get_drag_data` / `_can_drop_data` / `_drop_data`), pas une réimplémentation :

- une case d'objet (`ItemTile`) fournit `{"kind": "item", "item_id": …}` ;
- une case rapide (`HotbarSlot`) accepte un objet **ou** une autre case rapide ;
  elle transmet alors `swap:<index>` ;
- le panneau traduit le dépôt en `GameState.set_hotbar_item()` ou
  `GameState.swap_hotbar_items()`, puis reconstruit la rangée ;
- aucun `ItemData` n'est dupliqué dans l'interface : tout est relu depuis
  `Database`.

L'aperçu de glisser est un panneau avec le nom de l'objet (léger, lisible sans
rendu 3D). Le même code de dépôt est exposé publiquement via
`InventoryPanel.assign_hotbar(index, item_id)` pour les tests.

### Filtres et tri

Le tri suit l'ordre des catégories de `CATEGORY_ORDER`, puis le nom affiché.
Les filtres sont indépendants de l'inventaire réel : les objets à quantité nulle
ne sont jamais affichés.

## 2. Barre rapide

- `GameState.hotbar_items` : 5 identifiants, `hotbar_index` : case sélectionnée.
- Touches `1`–`5` (`hotbar_1`…`hotbar_5` de l'InputMap) et clic dans le panneau.
- **F** utilise l'objet consommable sélectionné (`GameState.use_selected_item()`).
- HUD : icône + nom + quantité par case ; la case sélectionnée est surlignée,
  les cases vides sont grisées. Le contenu est rafraîchi par `hotbar_changed`.

API :

| Méthode | Rôle |
|---|---|
| `set_hotbar_item(index, item_id)` | assigne un objet (`""` vide la case), refuse un id inconnu ou un index hors bornes |
| `swap_hotbar_items(a, b)` | échange deux cases (réorganisation) |
| `select_hotbar(index)` | change la case sélectionnée (bornée) |
| `selected_hotbar_item()` | id de la case courante |

## 3. HUD

- **Quatre jauges** : vie, faim, soif, **fatigue** (nouvelle en v3), mises à jour
  chaque image depuis `GameState.stats`.
- **Horloge**, boussole, invite d'interaction, toasts, suivi de quête.
- **Résumé d'inventaire** : « N objet(s), M type(s) — I : ouvrir » au lieu de la
  liste complète (la liste détaillée vit dans le panneau **I**).
- **Aide F1** : liste toutes les commandes, dont `I`, `Tab` et `Ctrl+Y`.

## 4. Règles d'architecture respectées

1. **Data-driven** : rien n'est codé en dur par objet ; catégories, noms, icônes
   et descriptions viennent des `.tres`.
2. **GameState central** : le panneau ne touche jamais `inventory` ni
   `hotbar_items` en écriture directe.
3. **UI à l'écoute** : `inventory_changed` et `hotbar_changed` déclenchent les
   reconstructions ; aucune vue n'est propriétaire de l'état.
4. **Sauvegarde** : `hotbar_items`, `hotbar_index` et `inventory` sont déjà
   sérialisés dans le format v3 (voir [`10-sauvegarde-ui.md`](10-sauvegarde-ui.md)).

## 5. Tests

`./run.sh --test` vérifie :

- les actions `toggle_inventory` et `toggle_help` dans l'InputMap ;
- l'assignation, l'échange et le refus (id inconnu, index hors bornes) de la
  barre rapide ;
- la présence d'une icône de case rapide ;
- l'ouverture / fermeture du panneau, ses filtres et sa recherche ;
- le dépôt simulé d'un objet (même chemin que le glisser-déposer) et le refus
  d'un objet inconnu ;
- la synchronisation de la jauge de fatigue avec `GameState.stats`.

## 6. Validation manuelle

Le smoke test headless ne rend pas l'interface et ne simule pas la souris. À
vérifier en session graphique :

- lisibilité des icônes et des quantités dans la grille et la barre rapide ;
- glisser-déposer d'un objet vers une case rapide, puis échange case ↔ case ;
- comportement de la souris (mode visible dans les panneaux, recapture à la
  fermeture) et de **Échap** / **I** ;
- lisibilité de la jauge de fatigue et du résumé d'inventaire.

## Voir aussi

- [`03-survie.md`](03-survie.md) — jauges et consommation
- [`05-artisanat.md`](05-artisanat.md) — panneau d'artisanat
- [`10-sauvegarde-ui.md`](10-sauvegarde-ui.md) — sauvegarde et signaux
- [`12-donnees.md`](12-donnees.md) — `ItemData`, icônes procédurales
