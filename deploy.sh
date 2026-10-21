#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$APP_DIR"

if [[ ! -f .env ]]; then
  echo "ERROR: .env not found."
  echo "Run: cp .env.example .env && nano .env"
  exit 1
fi

if ! grep -Eq '^TUNNEL_TOKEN=.+$' .env || grep -Eq '^TUNNEL_TOKEN=(PASTE_CLOUDFLARE_TUNNEL_TOKEN_HERE)?$' .env; then
  echo "ERROR: Set TUNNEL_TOKEN in .env using the token from Cloudflare Zero Trust."
  exit 1
fi

# Load the configured external network name without executing .env as shell code.
NETWORK_NAME="$(sed -n 's/^NPM_DOCKER_NETWORK=//p' .env | tail -n 1 | tr -d '\r' | sed 's/^"//; s/"$//; s/^\x27//; s/\x27$//')"
NETWORK_NAME="${NETWORK_NAME:-npm_network}"

if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  echo "ERROR: Docker network '$NETWORK_NAME' does not exist."
  echo "Find the network used by Nginx Proxy Manager:"
  echo "  docker inspect <npm-container-name> --format '{{json .NetworkSettings.Networks}}'"
  echo "Set NPM_DOCKER_NETWORK in .env to that exact network name."
  exit 1
fi

docker compose config --quiet
docker compose up -d
echo
echo "Cloudflare Tunnel container started. Check logs with:"
echo "  docker compose logs -f cloudflared"
