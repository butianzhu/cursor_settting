#!/bin/bash
# Merge existing compile_commands.json from build_<type>_<fru> dirs into
# .clangd_build/compile_commands.json (same jq rule as generate_compile_commands.sh).
# Does not run Cbuild or make — use after builds already produced compile_commands.json.
#
# Usage: ./etc/merge_compile_commands.sh [sim|hw] [fru_list]
#   sim|hw     Build type (default: sim)
#   fru_list   Comma-separated FRUs (default: frcug3x,chmqs)
#
# Also considers build_<type>_sh1b if compile_commands.json exists there (same as generate script).
#
# Examples:
#   ./etc/merge_compile_commands.sh
#   ./etc/merge_compile_commands.sh sim frcug3x,chmqs
#   ./etc/merge_compile_commands.sh sim chmqs,frcug3x

set -euo pipefail


ThanosDir=$(realpath "$(dirname "$0")/..")
BUILD_TYPE="${1:-sim}"
FRU_LIST="${2:-frcug3x,chmqs}"

echo "Merging compile_commands.json (one entry per file)..."

if [[ "$BUILD_TYPE" != "sim" && "$BUILD_TYPE" != "hw" ]]; then
  echo "Error: build type must be 'sim' or 'hw', got: $BUILD_TYPE"
  exit 1
fi

IFS=',' read -ra FRUS <<< "$FRU_LIST"
BUILD_DIRS=()
for fru in "${FRUS[@]}"; do
  fru="${fru// /}"
  [[ -n "$fru" ]] && BUILD_DIRS+=("$ThanosDir/build_${BUILD_TYPE}_${fru}")
done

compile_cmd_files=()
for build_dir in "${BUILD_DIRS[@]}"; do
  cc="$build_dir/compile_commands.json"
  if [[ -f "$cc" ]]; then
    compile_cmd_files+=("$cc")
    echo "Including: $cc"
  else
    echo "Skipping (missing): $cc"
  fi
done

if [[ ${#compile_cmd_files[@]} -eq 0 ]]; then
  echo "Error: no compile_commands.json found in any build directory"
  exit 1
fi

mkdir -p "$ThanosDir/.clangd_build"
jq -s 'add | unique_by(.file)' "${compile_cmd_files[@]}" > "$ThanosDir/.clangd_build/compile_commands.json"

echo "Done: $ThanosDir/.clangd_build/compile_commands.json ($(jq length "$ThanosDir/.clangd_build/compile_commands.json") entries)"