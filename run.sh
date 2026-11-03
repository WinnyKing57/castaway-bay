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

if [ ! -x "$GODOT_BIN" ]; then
  GODOT_BIN="flatpak run org.godotengine.Godot"
fi

if [ "${1:-}" != "--editor" ]; then
  if [ ! -f ".godot/global_script_class_cache.cfg" ]; then
    $GODOT_BIN --headless --path . --import >/dev/null 2>&1 || true
  fi
fi

case "${1:-}" in
  --play)
    exec $GODOT_BIN --path .
    ;;
  --test)
    exec $GODOT_BIN --headless --path . -- --smoke-test
    ;;
  --overview)
    exec $GODOT_BIN --path .
    ;;
  *)
    exec $GODOT_BIN --editor --path .
    ;;
esac
