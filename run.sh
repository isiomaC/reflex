#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
derived_data_path="${REFLEX_DERIVED_DATA_PATH:-$root_dir/.build}"

"$root_dir/build.sh" >/dev/null

app_path="$derived_data_path/Build/Products/Debug/Reflex.app"
if [[ ! -d "$app_path" ]]; then
  printf 'Build succeeded but Reflex.app was not found at %s\n' "$app_path" >&2
  exit 1
fi

open "$app_path"
