# 11 — Tests et outils de développement

## 1. Smoke test

```bash
./run.sh --test   # doit afficher : SMOKE_TEST OK
```

Couverture (headless) :

- Socle : île, nage, récolte, artisanat, construction, sauvegarde.
- Inventaire : retraits / coûts négatifs-nuls refusés.
- Persistance : sauvegarde / chargement, fichiers corrompus rejetés.
- Artisanat : fabrication chronométrée, annulation.
- Construction : chevauchements, niveaux, undo, toits.
- Marchand : réputation, trocs, quêtes, journal, panneaux.
- Bateau : libération, réparation.
- Monde : biomes (forêt / plaine / ferme / plage / montagne), grottes,
  minerais profonds, point d'échouage, cultures.

## 2. Outils de développement

- `--overview` : vue aérienne de l'île générée (vérification du terrain).
- `--show-crafting` : ouvre l'artisanat directement.

## 3. CI

- GitHub Actions : exécution de `./run.sh --test` en headless.

## 4. Export

```bash
./build/linux/castaway-bay.x86_64 --headless -- --smoke-test
```

## Voir aussi

- [`../README.md`](../README.md) — section « Lancer le jeu »
- [`../TODO.md`](../TODO.md) — tests restants
