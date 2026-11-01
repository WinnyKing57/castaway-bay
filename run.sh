#!/usr/bin/env bash
# Lance Castaway Bay (installation Flatpak de Godot).
#
#   ./run.sh              -> ouvre l'éditeur Godot sur le projet
#   ./run.sh --play       -> lance le jeu directement
#   ./run.sh --test       -> test d'intégration sans fenêtre
#   ./run.sh --overview   -> lance le jeu en vue aérienne (debug)
set -euo pipefail
cd "$(dirname "$0")"

GODOT=(flatpak run org.godotengine.Godot)

case "${1:-}" in
  --play)
    exec "${GODOT[@]}" --path .
    ;;
  --test)
    exec "${GODOT[@]}" --headless --path . -- --smoke-test
    ;;
  --overview)
    exec "${GODOT[@]}" --path . -- --overview
    ;;
  *)
    exec "${GODOT[@]}" --editor --path .
    ;;
esac
