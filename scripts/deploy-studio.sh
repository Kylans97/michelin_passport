#!/usr/bin/env bash
# Deploys studio/ to the Cloudflare Pages project mantelier-studio
# (studio.mantelier.app), with the current commit stamped into the
# asset URLs: /studio.js?v=<commit>.
#
# Why: the mantelier.app zone's Browser Cache TTL (4 hours) overrides the
# Cache-Control that studio/_headers sends, so on studio.mantelier.app a
# browser can keep an old studio.js next to a new index.html — new buttons
# with no handlers (2026-11-02). A new URL per deploy sidesteps that cache.
# index.html itself is served with max-age=0, so it always names the
# current version.
#
# Run from the repository root:  scripts/deploy-studio.sh
set -euo pipefail

version="$(git rev-parse --short HEAD)"
if [ -n "$(git status --porcelain -- studio)" ]; then
  version="${version}-dirty"
fi

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
cp -R studio/. "$out/"
sed -i '' "s/__STUDIO_VERSION__/${version}/g" "$out/index.html"

echo "Deploying studio/ at ${version}"
npx --yes wrangler@3 pages deploy "$out" --project-name mantelier-studio --branch main
