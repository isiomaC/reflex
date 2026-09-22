#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
derived_data_path="${REFLEX_DERIVED_DATA_PATH:-$root_dir/.build}"

xcodebuild \
  -project "$root_dir/Reflex.xcodeproj" \
  -scheme Reflex \
  -configuration Debug \
  -derivedDataPath "$derived_data_path" \
  build

printf '%s\n' "$derived_data_path/Build/Products/Debug/Reflex.app"
