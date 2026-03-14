#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_NAME="${WORKFLOW_NAME:-iOS (unsigned IPA)}"
BRANCH_NAME="${BRANCH_NAME:-master}"
ARTIFACT_NAME="${ARTIFACT_NAME:-Tyflocentrum-unsigned-ipa}"

DEST_DIR="${DEST_DIR:-artifacts}"
DEST_FILE="${DEST_FILE:-tyflocentrum.ipa}"

run_id="${1:-}"
if [[ -z "$run_id" ]]; then
  run_id="$(
    gh run list \
      --workflow "$WORKFLOW_NAME" \
      --branch "$BRANCH_NAME" \
      --status success \
      --limit 1 \
      --json databaseId \
      --jq '.[0].databaseId'
  )"
fi

if [[ -z "$run_id" ]]; then
  echo "No successful run found for workflow \"$WORKFLOW_NAME\" on branch \"$BRANCH_NAME\"." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
cleanup() { rm -r "$tmp_dir" 2>/dev/null || true; }
trap cleanup EXIT

gh run download "$run_id" --name "$ARTIFACT_NAME" --dir "$tmp_dir" >/dev/null

ipa_path="$(find "$tmp_dir" -type f -name '*.ipa' | head -n 1 || true)"
if [[ -z "$ipa_path" ]]; then
  echo "No .ipa found in artifact \"$ARTIFACT_NAME\" for run $run_id." >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
cp -f "$ipa_path" "$DEST_DIR/$DEST_FILE"
echo "Saved $DEST_DIR/$DEST_FILE (from run $run_id)."
