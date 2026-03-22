#!/usr/bin/env bash
# status.sh - show container health, Tailscale connection, and proxy reachability.
set -euo pipefail

PRIVOXY_PORT="${PRIVOXY_PORT:-8118}"
PROXY="http://127.0.0.1:${PRIVOXY_PORT}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

read_env_value() {
	local key="$1"

	[[ -f "$ENV_FILE" ]] || return 0

	while IFS='=' read -r name value; do
		[[ "$name" == "$key" ]] || continue
		value="${value%\"}"
		value="${value#\"}"
		printf '%s\n' "$value"
		return 0
	done <"$ENV_FILE"
}

PRIVATE_SUFFIXES="$(read_env_value PRIVATE_DNS_SUFFIXES)"
if [[ -z "$PRIVATE_SUFFIXES" ]]; then
	PRIVATE_SUFFIXES="$(read_env_value WORK_TLDS)"
fi

echo "=== Container status ==="
docker compose ps
echo ""

echo "=== Tailnet status ==="
docker exec tailnet-gateway tailscale status 2>/dev/null || echo "(daemon not running or not connected)"
echo ""

echo "=== Private DNS suffixes ==="
if [[ -n "$PRIVATE_SUFFIXES" ]]; then
	for suffix in $PRIVATE_SUFFIXES; do
		echo "  .${suffix}"
	done
else
	echo "(none - set PRIVATE_DNS_SUFFIXES in .env, e.g. PRIVATE_DNS_SUFFIXES=corp internal)"
fi
echo ""

echo "=== Proxy reachability ==="
if http_code="$(curl -sf -x "$PROXY" -o /dev/null -w "%{http_code}" http://example.com)"; then
	echo "HTTP proxy OK - HTTP ${http_code} via ${PROXY}"
	echo ""
	echo "Shell env vars needed on host:"
	echo "  export http_proxy=${PROXY} https_proxy=${PROXY}"
	echo "  export no_proxy=localhost,127.0.0.1,::1"
else
	echo "HTTP proxy is not reachable at ${PROXY}"
	echo "Run: docker compose logs http-proxy"
fi
