#!/usr/bin/env bash
# Build the 3 source-built Muffin images for ARM64 (Oracle A1) and push to GHCR.
#
# Prereqs:
#   - `docker login ghcr.io` with a PAT that has write:packages
#   - Docker buildx (bundled with Docker Desktop). On Apple Silicon arm64 builds
#     are native; on Intel they run under qemu emulation (slower but works).
#   - langgraph CLI available in the muffin-agent environment (it's a dev dep):
#       cd muffin-agent && pip install -e ".[dev]"   (or: uv pip install langgraph-cli)
#
# Usage:
#   REGISTRY=ghcr.io/<user>/muffin DOMAIN=example.com ./build-and-push.sh
#   (API_URL defaults to https://api.$DOMAIN — must match secrets.yaml api_subdomain)
set -euo pipefail

# --- config ---------------------------------------------------------------
REGISTRY="${REGISTRY:?set REGISTRY, e.g. ghcr.io/<user>/muffin}"
DOMAIN="${DOMAIN:-}"
API_URL="${API_URL:-${DOMAIN:+https://api.${DOMAIN}}}"
PLATFORM="${PLATFORM:-linux/arm64}"            # A1 instances are aarch64
: "${API_URL:?set API_URL or DOMAIN so the chat UI is baked with the right API base URL}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# muffin-agent is a sibling repo: oracle-cloud-docker-swarm-setup/ and muffin-agent/
MUFFIN_AGENT_DIR="${MUFFIN_AGENT_DIR:-$(cd "$SCRIPT_DIR/../../../../muffin-agent" && pwd)}"

echo "Registry:        $REGISTRY"
echo "Platform:        $PLATFORM"
echo "UI API base URL: $API_URL"
echo "muffin-agent:    $MUFFIN_AGENT_DIR"
echo

# Ensure a buildx builder exists.
docker buildx inspect muffin-builder >/dev/null 2>&1 || docker buildx create --name muffin-builder --use
docker buildx use muffin-builder

# --- 1. LangGraph agent server -------------------------------------------
# Generate the Dockerfile from langgraph.json, then buildx it for arm64.
echo "==> Building $REGISTRY:api (langgraph agent server)"
pushd "$MUFFIN_AGENT_DIR" >/dev/null
langgraph dockerfile ./Dockerfile.langgraph
docker buildx build --platform "$PLATFORM" --push \
  -t "$REGISTRY:api" -f ./Dockerfile.langgraph .
rm -f ./Dockerfile.langgraph
popd >/dev/null

# --- 2. OpenBB MCP server -------------------------------------------------
echo "==> Building $REGISTRY:openbb (OpenBB MCP server)"
docker buildx build --platform "$PLATFORM" --push \
  -t "$REGISTRY:openbb" "$MUFFIN_AGENT_DIR/extras/openbb"

# --- 3. Agent Chat UI (bakes the public API URL) -------------------------
echo "==> Building $REGISTRY:ui (agent-chat-ui, NEXT_PUBLIC_API_URL=$API_URL)"
docker buildx build --platform "$PLATFORM" --push \
  --build-arg "NEXT_PUBLIC_API_URL=$API_URL" \
  -t "$REGISTRY:ui" "$MUFFIN_AGENT_DIR/extras/agent-chat-ui"

echo
echo "Done. Pushed: $REGISTRY:{api,openbb,ui}"
