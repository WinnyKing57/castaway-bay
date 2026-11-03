#!/usr/bin/env bash
# Lance Castaway Bay (build Linux exporté) ou éditeur Godot.
#
#   ./run.sh              -> ouvre l'éditeur Godot sur le projet
#   ./run.sh --play       -> lance le jeu directement
#   ./run.sh --test       -> test d'intégration sans fenêtre
#   ./run.sh --overview   -> lance le jeu en vue aérienne (debug)
set -euo pipefail
cd "$(dirname "$0")"

GODOT_BIN="${GODOT_BIN:-/tmp/opencode/godot/Godot_v4.7-stable_linux.x86_64}"
GODOT=(flatpak run org.godotengine.Godot)

if [ -x "$GODOT_BIN" ]; then
	GODOT=("$GODOT_BIN")
fi

case "${1:-}" in
  --play)
    exec "${GODOT[@]}" --path .
    ;;
  --test)
    exec "${GODOT[@]}" --headless --path . -- --smoke-test
    ;;
  --overview)
    exec "${GODOT[@]}" --path .
    ;;
  *)
    exec "${GODOT[@]}" --editor --path .
    ;;
esac
