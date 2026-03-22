# No official Privoxy image exists on Docker Hub — available third-party images
# are individually maintained, not by the Privoxy project. Building from Alpine
# (official image) + Alpine package repos gives a known, auditable supply chain
# with no hidden layers.
# To pin to a digest: docker inspect http-proxy --format='{{index .RepoDigests 0}}'
FROM alpine:3.19
RUN apk add --no-cache privoxy curl dnsmasq
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 8118
ENTRYPOINT ["/entrypoint.sh"]
