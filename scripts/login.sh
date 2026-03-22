#!/usr/bin/env bash
# login.sh — trigger Tailscale auth and surface the login URL.
set -euo pipefail

CONTAINER="tailnet-gateway"

# Check the container is running
if ! docker inspect "$CONTAINER" --format '{{.State.Running}}' 2>/dev/null | grep -q true; then
	echo "Container '$CONTAINER' is not running. Run 'make up' first."
	exit 1
fi

# If already authenticated, nothing to do
if docker exec "$CONTAINER" tailscale status 2>/dev/null | grep -q '100\.'; then
	echo "Already authenticated."
	docker exec "$CONTAINER" tailscale status
	exit 0
fi

echo "Starting Tailscale login..."
echo "(Approval may be required after you authenticate.)"
echo ""

# `tailscale login` prints the auth URL then blocks until authenticated.
# Run it in the foreground — the user sees the URL and it exits when done.
docker exec -it "$CONTAINER" tailscale login

echo ""
echo "Authenticated. Run 'make status' to verify everything is up."
