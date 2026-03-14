#!/usr/bin/env bash
set -euo pipefail

BASE_SHA="${1:-}"
HEAD_SHA="${2:-}"

if [[ -z "$BASE_SHA" || -z "$HEAD_SHA" ]]; then
  echo "Usage: $0 <base_sha> <head_sha>" >&2
  exit 2
fi

if ! git cat-file -e "$BASE_SHA^{commit}" 2>/dev/null; then
  echo "::error::Base commit not found locally: $BASE_SHA (did you checkout with fetch-depth: 0?)" >&2
  exit 2
fi

if ! git cat-file -e "$HEAD_SHA^{commit}" 2>/dev/null; then
  echo "::error::Head commit not found locally: $HEAD_SHA" >&2
  exit 2
fi

changed_files="$(git diff --name-status "$BASE_SHA...$HEAD_SHA")"

if [[ -z "${changed_files//[[:space:]]/}" ]]; then
  echo "No changed files detected between $BASE_SHA...$HEAD_SHA."
  exit 0
fi

docs_touched=false
requires_docs=false
trigger_files=()

# Heuristic: require docs only for "public surface" changes (new features, API/architecture, build/CI).
# This is intentionally NOT every code change.
public_surface_paths=(
  "Tyflocentrum/TyfloAPI.swift"
  "Tyflocentrum/AudioPlayer.swift"
  "Tyflocentrum/SettingsStore.swift"
  "Tyflocentrum/Views/SettingsView.swift"
  "Tyflocentrum/FavoritesStore.swift"
  "Tyflocentrum/Views/FavoritesView.swift"
  "Tyflocentrum/Views/ContentView.swift"
  "Tyflocentrum/Views/AppMenu.swift"
  "Tyflocentrum/Views/ContactView.swift"
  "Tyflocentrum/Info.plist"
)

while IFS= read -r status path1 path2; do
  [[ -z "$status" ]] && continue

  file="$path1"
  # For rename/copy, take destination path.
  case "$status" in
    R*|C*)
      file="$path2"
      ;;
  esac

  [[ -z "$file" ]] && continue

  case "$file" in
    README.md|docs/*)
      docs_touched=true
      ;;
  esac

  case "$file" in
    README.md|docs/*)
      continue
      ;;
  esac

  case "$file" in
    .github/workflows/readme-guard.yml|scripts/require-readme-update.sh)
      continue
      ;;
  esac

  case "$file" in
    Tyflocentrum.xcodeproj/*|Tyflocentrum.xcdatamodeld/*|.github/workflows/*|scripts/*|installers/*)
      requires_docs=true
      trigger_files+=("$file")
      ;;
  esac

  # Public surface changes (API/architecture/user-facing mechanics)
  for path in "${public_surface_paths[@]}"; do
    if [[ "$file" == "$path" ]]; then
      requires_docs=true
      trigger_files+=("$file")
      break
    fi
  done

  # New user-facing files: adding Views/Models is almost always a new feature worth documenting.
  if [[ "$requires_docs" != "true" ]]; then
    case "$status" in
      A*)
        case "$file" in
          Tyflocentrum/Views/*.swift|Tyflocentrum/Models/*.swift)
            requires_docs=true
            trigger_files+=("$file")
            ;;
        esac
        ;;
    esac
  fi
done <<< "$changed_files"

if [[ "$requires_docs" == "true" && "$docs_touched" != "true" ]]; then
  {
    echo "::error::Documentation update is required for this change but neither README.md nor docs/ were updated."
    echo "::error::Update README.md or add/update docs under docs/ when changing app/build/workflow/scripts."
    echo ""
    echo "Files triggering the requirement (first 50):"
    printf -- "- %s\n" "${trigger_files[@]:0:50}"
    echo ""
    echo "All changed files:"
    echo "$changed_files" | sed 's/^/- /'
  } >&2
  exit 1
fi

echo "Docs guard passed."
