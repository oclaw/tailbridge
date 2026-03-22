#!/usr/bin/env bash
# add-domain.sh - add a private DNS suffix to .env.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
TARGET_KEY="PRIVATE_DNS_SUFFIXES"
LEGACY_KEY="WORK_TLDS"

usage() {
	echo "Usage: $0 <suffix>"
	echo "  Example: $0 internal"
	echo "  Adds the suffix to ${TARGET_KEY} in .env so dnsmasq routes it via the tailnet DNS server."
	exit 1
}

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

write_env_value() {
	local key="$1"
	local value="$2"
	local tmp_file
	local wrote=0

	tmp_file="$(mktemp)"

	while IFS= read -r line || [[ -n "$line" ]]; do
		case "$line" in
		"${key}="* | "${LEGACY_KEY}="*)
			if [[ $wrote -eq 0 ]]; then
				printf '%s=%s\n' "$key" "$value" >>"$tmp_file"
				wrote=1
			fi
			;;
		*)
			printf '%s\n' "$line" >>"$tmp_file"
			;;
		esac
	done <"$ENV_FILE"

	if [[ $wrote -eq 0 ]]; then
		printf '%s=%s\n' "$key" "$value" >>"$tmp_file"
	fi

	mv "$tmp_file" "$ENV_FILE"
}

[[ $# -eq 0 ]] && usage

SUFFIX="${1#.}"
[[ -z "$SUFFIX" ]] && usage

if [[ ! "$SUFFIX" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
	echo "Error: '${SUFFIX}' is not a valid DNS suffix."
	exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
	echo "Error: .env not found at ${ENV_FILE}"
	echo "Run: cp .env.example .env"
	exit 1
fi

CURRENT="$(read_env_value "$TARGET_KEY")"
if [[ -z "$CURRENT" ]]; then
	CURRENT="$(read_env_value "$LEGACY_KEY")"
fi

if [[ " ${CURRENT} " == *" ${SUFFIX} "* ]]; then
	echo "Suffix '${SUFFIX}' is already configured - no changes made."
	exit 0
fi

NEW_VALUE="${CURRENT:+${CURRENT} }${SUFFIX}"
write_env_value "$TARGET_KEY" "$NEW_VALUE"

echo "Updated ${TARGET_KEY}: ${NEW_VALUE}"
echo ""
echo "Restarting HTTP proxy..."
docker compose -f "${SCRIPT_DIR}/../docker-compose.yml" restart http-proxy
echo "Done. Run 'make status' to verify."
