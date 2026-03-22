#!/usr/bin/env bash
# doctor.sh - run automated checks for the tailbridge stack.
set -euo pipefail

PRIVOXY_PORT="${PRIVOXY_PORT:-8118}"
PROXY="http://127.0.0.1:${PRIVOXY_PORT}"

pass() {
	printf '[ok] %s\n' "$1"
}

fail() {
	printf '[fail] %s\n' "$1" >&2
	exit 1
}

check_running() {
	local container="$1"
	local value

	value="$(docker inspect "$container" --format '{{.State.Running}}' 2>/dev/null || true)"
	[[ "$value" == "true" ]] || fail "${container} is not running"
	pass "${container} is running"
}

check_health() {
	local container="$1"
	local value

	value="$(docker inspect "$container" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' 2>/dev/null || true)"
	case "$value" in
	healthy)
		pass "${container} healthcheck is healthy"
		;;
	none)
		pass "${container} has no healthcheck"
		;;
	*)
		fail "${container} healthcheck status is ${value}"
		;;
	esac
}

echo "== Container checks =="
check_running tailnet-gateway
check_health tailnet-gateway
check_running http-proxy
check_health http-proxy

echo ""
echo "== Tailscale checks =="
if docker exec tailnet-gateway tailscale status 2>/dev/null | grep -q '100\.'; then
	pass "tailnet connection is established"
else
	fail "tailnet connection is not established"
fi

if docker exec tailnet-gateway ip route show table 52 2>/dev/null | grep -q .; then
	pass "policy routes are present in table 52"
else
	fail "no routes found in policy table 52"
fi

echo ""
echo "== DNS and proxy checks =="
if docker exec http-proxy sh -c 'ps | grep [d]nsmasq >/dev/null'; then
	pass "dnsmasq is running inside http-proxy"
else
	fail "dnsmasq is not running inside http-proxy"
fi

if docker exec http-proxy sh -c 'grep -qx "nameserver 127.0.0.1" /etc/resolv.conf'; then
	pass "http-proxy uses local dnsmasq"
else
	fail "http-proxy is not configured to use local dnsmasq"
fi

if curl -sf -x "$PROXY" -o /dev/null http://example.com; then
	pass "HTTP proxy can reach public destinations"
else
	fail "HTTP proxy cannot reach public destinations"
fi

echo ""
echo "== Optional private host check =="
if [[ -n "${PRIVATE_TEST_HOST:-}" ]]; then
	if curl -sf -x "$PROXY" -o /dev/null "http://${PRIVATE_TEST_HOST}"; then
		pass "private host ${PRIVATE_TEST_HOST} is reachable through the proxy"
	else
		fail "private host ${PRIVATE_TEST_HOST} is not reachable through the proxy"
	fi
else
	printf '[skip] Set PRIVATE_TEST_HOST to verify a private endpoint\n'
fi
