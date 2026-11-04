# Sources d'inspiration

Ce fichier documente les références externes utilisées pour s'inspirer de l'architecture, du gameplay et du visuel. 
Ces projets ne sont **pas** inclus dans le dépôt (hors-scope) pour éviter de le polluer. 
Ils sont clonés à l'extérieur du repo git de Castaway Bay.

## Emplacements

| Repo | Emplacement local | Description | Usage |
|---|---|---|---|
| [tomlooman/ActionRoguelike](https://github.com/tomlooman/ActionRoguelike) | `~/autre/github/jeu/references/ActionRoguelike/` | Projet Unreal Engine C++ (Action Roguelike course). | Architecture gameplay, systèmes d'action/compétences, IA, UI data-driven, patterns de code propre. À adapter aux concepts Godot/GDScript. |
| [tomlooman/EpicSurvivalGame](https://github.com/tomlooman/EpicSurvivalGame) | `~/autre/github/jeu/references/EpicSurvivalGame/` | Projet Unreal Engine C++ (Survival Game). | Survie (jauges, faim/soif), inventaire, crafting, construction, ressources, état du joueur, atmosphère. Idées à transposer à notre approche Godot low-poly. |

## Comment les utiliser

1. Cloner hors du repo :
```bash
mkdir -p ~/autre/github/jeu/references
git clone --depth 1 https://github.com/tomlooman/ActionRoguelike.git ~/autre/github/jeu/references/ActionRoguelike
git clone --depth 1 https://github.com/tomlooman/EpicSurvivalGame.git ~/autre/github/jeu/references/EpicSurvivalGame
```

2. Étudier les patterns, pas copier le code tel quel. Traduire les concepts vers GDScript/Godot :
   - **Architecture** : composants, autoloads/singletons, data-driven (Resources)
   - **UI** : organisation HUD/menus, feedback visuel
   - **Survie/Construction** : logique de placement, validation, matériaux
   - **Visuel/Graphisme** : idées de modèles low-poly, éclairage, matériaux
   - **Personnages/Animations** : approche des rigs, états

3. Documenter les idées retenues dans `IDEAS.md` avec contexte.

## Notes

- Ces projets sont en Unreal Engine C++. L'objectif est l'inspiration conceptuelle/architecturale, pas un portage direct.
- Ne jamais committer ces références dans le repo git de Castaway Bay.
- Garder les chemins dans ce fichier pour référence rapide.
