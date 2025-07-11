#!/bin/bash

# === Script Directory ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}"

echo "Applying *.template files in $CONFIG_DIR (only if missing)..."

cd "$CONFIG_DIR" || exit 1

for tmpl in *.template; do
  [[ -f "$tmpl" ]] || continue
  target="${tmpl%.template}"
  if [[ -f "$target" ]]; then
    echo "  Skipping $target (already exists)"
  else
    cp "$tmpl" "$target"
    echo "  Created $target from $tmpl"
  fi
done

echo "Template application complete."
