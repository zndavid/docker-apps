#!/usr/bin/env sh
set -eu

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker CLI is required for compose validation." >&2
  exit 1
fi

if [ ! -f .env ]; then
  cp .env.example .env
fi

docker compose -f docker-compose.yml config >/dev/null
echo "Compose config is valid."
