#!/usr/bin/env bash
# Fetch the latest phone + Wear OS release APKs from GitHub Actions
# and drop them into the public downloads/ folder so the landing page
# at mood8.app/download/ serves the freshest builds.
#
# Run on the box: ./scripts/fetch_apks.sh
# One-time setup:  gh auth login   (only needs to be done once per box)
#
# Exits 0 if anything was updated, 0 if nothing changed, non-zero on
# auth / network failure so the script is safe to wire into cron.

set -euo pipefail

REPO="Overover1400/mood8"
DEST="$(cd "$(dirname "$0")/.." && pwd)/downloads"

if ! command -v gh >/dev/null 2>&1; then
  echo "fatal: gh CLI is not installed. Install from https://cli.github.com/" >&2
  exit 2
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "fatal: gh CLI not authenticated. Run: gh auth login" >&2
  exit 2
fi

mkdir -p "$DEST"

# fetch_latest <workflow-file> <artifact-glob> <dest-filename>
#
# Picks the most recent SUCCESSFUL run of the named workflow on the
# default branch, downloads the matching artifact, and renames the
# inner .apk to <dest-filename> in $DEST. Artifact names from these
# workflows vary by run (e.g. mood8-android-apk-42) so we accept a
# glob via gh's --pattern.
fetch_latest() {
  local workflow="$1"
  local artifact_glob="$2"
  local dest_name="$3"
  local label="$4"

  echo ""
  echo "── $label ──────────────────────────────────────────────"

  local run_id
  run_id=$(gh run list \
    --repo "$REPO" \
    --workflow "$workflow" \
    --branch main \
    --status success \
    --limit 1 \
    --json databaseId \
    --jq '.[0].databaseId' 2>/dev/null || true)

  if [ -z "$run_id" ] || [ "$run_id" = "null" ]; then
    echo "  warn: no successful $workflow run found — skipping"
    return 0
  fi
  echo "  latest run: $run_id"

  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' RETURN

  if ! gh run download "$run_id" \
        --repo "$REPO" \
        --pattern "$artifact_glob" \
        --dir "$tmp" >/dev/null 2>&1; then
    echo "  warn: no artifact matching '$artifact_glob' on run $run_id"
    return 0
  fi

  local apk
  apk=$(find "$tmp" -name '*.apk' -size +1M | head -n1 || true)
  if [ -z "$apk" ]; then
    echo "  warn: artifact downloaded but no .apk inside it"
    return 0
  fi

  local size
  size=$(du -h "$apk" | cut -f1)
  mv "$apk" "$DEST/$dest_name"
  echo "  copied → $DEST/$dest_name ($size)"
}

fetch_latest "android-build.yml" "mood8-android-apk*" "mood8.apk"        "phone APK"
fetch_latest "wear-build.yml"    "mood8-wear-apk*"    "mood8-wear.apk"   "Wear OS APK"

echo ""
echo "done. Live URLs:"
echo "  https://mood8.app/download/mood8.apk"
echo "  https://mood8.app/download/mood8-wear.apk"
