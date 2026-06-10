#!/usr/bin/env bash
# Build the Mood8 web app for production.
#
# `--base-href "/app/"` is REQUIRED: nginx serves the Flutter SPA at
# https://mood8.app/app/ (the bare domain is the marketing landing
# page since 757d5dc). Without it the built index.html ships
# `<base href="/">`, asset fetches resolve to
# https://mood8.app/assets/... → 404 → white page on cold load.
#
# Run from the repo root:  ./scripts/build_web.sh
set -euo pipefail

flutter build web --release --base-href "/app/"

echo
echo "Built build/web with <base href=\"/app/\">."
echo "Reload nginx to serve the new bundle:"
echo "  sudo nginx -t && sudo systemctl reload nginx"
