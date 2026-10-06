#!/usr/bin/env bash
# Native pipeline: Prolog generator -> JSON -> Typst -> PDF.
# Usage: scripts/render.sh <game> <seed> [paper] [out.pdf]
set -euo pipefail

game=${1:?game}
seed=${2:?seed}
paper=${3:-a4}
out=${4:-out/$game-$seed.pdf}
root=$(cd "$(dirname "$0")/.." && pwd)

json=$(swipl -q -g 'current_prolog_flag(argv, [G, S|_]), generate_json(G, S, J), write(J)' \
  -t halt "$root/prolog/graphite.pl" -- "$game" "$seed")

mkdir -p "$(dirname "$out")"
typst compile --root "$root/typst" \
  --input "data=$json" --input "paper=$paper" \
  "$root/typst/$game.typ" "$out"
echo "$out"
