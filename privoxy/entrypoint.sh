#!/bin/sh
set -e

# Use a local dnsmasq as the container's resolver instead of the Docker-injected
# nameservers. Root cause: 100.100.100.100 is routed via tailscale0 (WireGuard
# tunnel), so every DNS query traverses the tunnel. Any latency spike causes a
# multi-second stall, which Privoxy treats as a DNS failure — for ALL domains,
# not just private-network ones.
#
# Split DNS strategy:
#   private suffixes → tailnet DNS (via tunnel — required)
#   everything else  → public DNS (direct, no tunnel — fast and reliable)
#
# PRIVATE_DNS_SUFFIXES: canonical variable, space-separated suffixes/domains to
# route via the tailnet DNS server. WORK_TLDS is still accepted for migration.

printf 'nameserver 127.0.0.1\n' >/etc/resolv.conf

PRIVATE_SUFFIXES="${PRIVATE_DNS_SUFFIXES:-${WORK_TLDS:-corp}}"
TAILNET_DNS_SERVER="${TAILNET_DNS_SERVER:-100.100.100.100}"
PUBLIC_DNS_PRIMARY="${PUBLIC_DNS_PRIMARY:-8.8.8.8}"
PUBLIC_DNS_SECONDARY="${PUBLIC_DNS_SECONDARY:-1.1.1.1}"

DNSMASQ_ARGS="--no-resolv --cache-size=500 --neg-ttl=0 --server=${PUBLIC_DNS_PRIMARY} --server=${PUBLIC_DNS_SECONDARY}"
for suffix in ${PRIVATE_SUFFIXES}; do
	DNSMASQ_ARGS="${DNSMASQ_ARGS} --server=/${suffix}/$TAILNET_DNS_SERVER"
done

# shellcheck disable=SC2086  # word splitting is intentional here
dnsmasq $DNSMASQ_ARGS

exec privoxy --no-daemon /etc/privoxy/config
