# 09 — Marché, réputation, quêtes et journal

Système complet du **marchand itinérant**, de la **réputation**, des **quêtes**
d'approvisionnement et du **livre de bord**.

## 1. Le marchand (`world/trader.gd`)

- Automate itinérant : géométrie low-poly (corps, tête, œil, antenne), collision.
- Interaction **E**.
- État persisté : position, `trade_count`, `_met` (rencontre).

## 2. Réputation

- Bornée 0-100.
- Paliers : **Méfiant**, **Neutre**, **Amical**, **Allié**.
- Chaque échange / quête rapporte des points ; journalisation des changements.

## 3. Troc direct (`data/trades/`)

- `TradeData` : `give` / `receive`, ressources échangées.
- Débloqués par paliers de réputation.
- Chaque échange rapporte +1 réputation.
- Vérifications : ressources disponibles, réputation suffisante.

## 4. Quêtes d'approvisionnement (`data/quests/`)

- `QuestData` : objets à fournir, récompenses, réputation minimale.
- Acceptation / remise, non répétables.
- Récompenses : objets + réputation.

## 5. Livre de bord (journal)

- Panneau **J**.
- 120 entrées max.
- Événements : rencontres, quêtes, découvertes, morts, respawn, paliers.

## 6. Épave de navire

- Générée sur le monde avec survivant — lot en cours.

## Voir aussi

- [`07-vehicules.md`](07-vehicules.md) — épave et navire
- [`10-sauvegarde-ui.md`](10-sauvegarde-ui.md) — persistance marchand/quêtes
- [`11-tests.md`](11-tests.md) — tests marchand
