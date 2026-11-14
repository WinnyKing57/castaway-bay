# 15 — Monde et PNJ (marchand / survivant)

Cette documentation couvre les PNJ principaux du monde : le marchand itinérant
de l'île et le survivant posté près de son épave.

## 1. Le marchand (`kind = "merchant"`)

**Rôle** : économie centralisée : offre des trocs débloquées par la réputation,
confie des quêtes d'approvisionnement, compte les échanges, gère la réputation du joueur.

**Interaction** : touche **E** → panneau `trader_panel.gd` qui montre : un label de dialogue,
une liste triée de trocs disponibles, une liste de quêtes acceptables et un bouton "Quitter".

**Comportement** :

- **Première rencontre** (`_met == false`) : le joueur est invité à parler ;
  le label de dialogue donne un premier aperçu ; le panneau se ferme quand le joueur tape **E** à nouveau.
  Un journal entry ("Rencontre avec un automate de troc rouillé, seul habitant de l'île.") est ajouté.

- **État par la réputation** : le texte de dialogue (`get_dialogue()`) et la liste des trocs (`get_available_trades()`)
  sont filtrés par `GameState.reputation` et les quêtes en cours (`accepted_quests`).

- **Trés / quêtes** : `execute_trade()` et `complete_quest()` ajoutent un point de réputation,
  génèrent un toast et des notifications de journal.

- **Sauvegarde** : les champs `position`, `rotation_y`, `met`, `trade_count` sont sauvegardés via
  `get_save_state()` / `apply_save_state()`. Le format v3 inclut le nouveau champ
  optionnel `kind` (par défaut `"merchant"` pour celui-ci).

**Architecture** : tout le texte de dialogue et les messages est contenu dans `world/trader.gd`.
Pas d'autres scripts, pas d'assets externes. Le seul état central est `GameState`,
le code est écrit en GDScript, la persistance via `SaveSystem`.

## 2. Le survivant (`kind = "survivor"`)

**Génération** : un `Trader` est instancié dans `world/island.gd` à côté de l'épave (`merchant_wreck.tscn`).
Son `kind` est forcé à `"survivor"` (identifié par son nom `Trader` qui lui-même
n'a pas de nom explicite).

**Interaction** : même touche **E**, même panneau (le panneau détermine le `get_node_or_null("/root/Main/World")`
et passe un nœud `Trader`).

**Comportement distinct** :

- **Première rencontre** (`kind == "survivor" && not _met`) : le label de dialogue est un message
  unique du survivant (« Je me souviens d'une galère naufragée… »), et le journal entry change :
  "Rencontre avec un survivant de l'épave du navire marchand."

- **État par la réputation** : après la première rencontre, le survivant se comporte exactement comme le marchand
  pour les trocs et les quêtes (même liste basée sur la réputation, mêmes récompenses).

- **Sauvegarde** : le champ `kind` est sauvegardé comme pour le marchand ; au chargement,
  l'attribut `kind` est restauré, permettant au survivant de conserver son identité même après
  une partie sauvegardée et rechargée.

**Pourquoi un survivant distinct ?** : le survivant représente un compagnon posté sur l'épave,
proposant un message narratif supplémentaire et un premier contact plus intime avec la carte.
Son existence ajoute un élément de découverte sans nouvelle logique de gameplay.

## 3. Sauvegarde et migration

- **v3** : ajoute le champ optionnel `kind` (par défaut `"merchant"`) ; les sauvegardes v1/v2
  ignorent le champ (ils ont leur propre format, restauré par le mécanisme de migration
  de `SaveSystem`).

- **Migration** : quand une sauvegarde v2 est chargée, un nouvel `Trader` est créé ; le champ `kind`
  n'est pas présent, donc `_met` et `trade_count` sont reconstruits depuis les
  sauvegardes v2 ; la logique par défaut (`kind = "merchant"`) assure la fonctionnalité.

- **Intégrité** : la validation (`_is_valid`) accepte n'importe quelle chaîne pour `kind`,
  mais la logique se limite à `"merchant"` et `"survivor"`.

## 4. Règles d'architecture

1. **Data-driven** : les offres de troc (`TradeData`) et les quêtes (`QuestData`) restent des données (`.tres`);
   le texte de dialogue est stocké comme code, pas en dur par statut.
2. **GameState central** : tous les changements d'état (réputation, inventaire, quêtes) passent par `GameState`.
3. **Interface unique** : un `Trader` gère à la fois les deux types via le champ `kind`;
   pas besoin d'une classe séparée `Survivor`.

## 5. Tests

- **Smoke test** (`./run.sh --test`) : instancie un monde, charge un `island.gd` complet avec
  alors les deux instances `Trader` ; vérifie que `world.get_trader()` retourne le
  marchand (premier) et que le survivant est présent (`survivor.kind == "survivor"`).
  Le test vérifie que le dialogue de première rencontre s'affiche et ajoute le journal.
- **Sauvegarde** : un cycle de sauvegarde-chargement complet restaure les deux traders,
  y compris leurs `kind` respectifs.
- **Persistance** : le survivant survit au nouveau jeu (`_on_menu_new_game`) car
  `GameState.reset()` n'efface pas les données des traders.

## 6. Validation manuelle

Dans une session graphique, le joueur peut :
1. Ouvrir le panneau (`E`) près du marchand (sur le chemin 60,0,60) → observe le
   dialogue de marchand.
2. Naviguer vers l'épave (générée aléatoirement sur la carte) et interagir (`E`) → observe
   la ligne de dialogue unique de survivant et le journal entry.
3. Revenir aux deux après un changement de carte (nouvelle île) : le marchand est
   réinstancié, le survivant aussi, chacun avec son `kind` restauré.

## Voir aussi

- [`07-vehicules.md`](07-vehicules.md) — reste pas concerné ; pour la référence de la carte.
- [`10-sauvegarde-ui.md`](10-sauvegarde-ui.md) — détails de la structure de sauvegarde.
- [`14-progression.md`](14-progression.md) — XP et niveaux.
- [`09-marche-repetition.md`](09-marche-repetition.md) — page complète du marchand dans la doc.

## Remarque

Le survivant ne dispose actuellement pas de stats supplémentaires (économie, missions).
Son existence sert principalement la narration et la découverte dans la carte du monde.
Pour une progression plus riche, un `Survivor` dédié pourrait être ajouté plus tard,
tout en réutilisant la logique de dialogue du marchand.