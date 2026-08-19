#!/usr/bin/env bash
set -euo pipefail

NAS_USER="${NAS_USER:-admin}"
NAS_HOST="${NAS_HOST:-192.168.178.78}"
NAS_PATH="${NAS_PATH:-/share/CACHEDEV1_DATA/Config/stack}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
REMOTE="${NAS_USER}@${NAS_HOST}"

echo "Syncing ${REPO_ROOT}/ -> ${REMOTE}:${NAS_PATH}/"

ssh "${REMOTE}" "mkdir -p '${NAS_PATH}'"

# Intentionally no --delete: NAS-only runtime files are preserved.
# Never overwrite the NAS runtime .env from a developer checkout.
rsync -rltvz --progress \
  --exclude '.git/' \
  --exclude '.env' \
  --exclude '.DS_Store' \
  --exclude 'Thumbs.db' \
  "${REPO_ROOT}/" \
  "${REMOTE}:${NAS_PATH}/"

echo "Done. Stack files are on ${REMOTE}:${NAS_PATH}/"
