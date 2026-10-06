#!/usr/bin/env bash
# Native pipeline: Prolog generator -> JSON -> Typst -> PDF.
# Usage: scripts/render.sh <game> <seed> [paper] [theme] [out.pdf]
#   paper: a4 | us-letter | pocket-a4 (A6 booklet imposed on A4 sheets)
set -euo pipefail

game=${1:?game}
seed=${2:?seed}
paper=${3:-a4}
theme=${4:-parkland}
out=${5:-out/$game-$seed-$theme-$paper.pdf}
root=$(cd "$(dirname "$0")/.." && pwd)

json=$(swipl -q -g 'current_prolog_flag(argv, [G, S|_]), generate_json(G, S, J), write(J)' \
  -t halt "$root/prolog/graphite.pl" -- "$game" "$seed")

compile() { # <page size> <output>
  typst compile --root "$root/typst" \
    --input "data=$json" --input "paper=$1" --input "theme=$theme" \
    "$root/typst/$game.typ" "$2"
}

mkdir -p "$(dirname "$out")"
if [ "$paper" = pocket-a4 ]; then
  pages="$root/out/.pocket-pages.pdf"
  mkdir -p "$root/out"
  compile a6 "$pages"
  # Typst writes page objects uncompressed, so they can be counted directly.
  count=$(LC_ALL=C grep -aoE '/Type ?/Page([^s[:alnum:]]|$)' "$pages" | wc -l | tr -d ' ')
  typst compile --root "$root" --input src=/out/.pocket-pages.pdf --input "pages=$count" \
    "$root/typst/impose.typ" "$out"
else
  compile "$paper" "$out"
fi
echo "$out"
