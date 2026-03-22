.DEFAULT_GOAL := help

.PHONY: help up down restart login status doctor logs logs-ts logs-proxy logs-privoxy add-domain test routes clean

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

up: ## Start all services (builds Privoxy image if needed)
	docker compose up -d --build

down: ## Stop all services
	docker compose down

restart: ## Restart all services
	docker compose restart

login: ## Show Tailscale login URL and wait for auth (first run only)
	@bash scripts/login.sh

routes: ## Re-apply route acceptance if state was reset, then show routes
	docker exec tailnet-gateway tailscale set --accept-routes
	@echo "Routes accepted. Verifying..."
	docker exec tailnet-gateway ip route show

status: ## Show container health, Tailscale connection, and proxy reachability
	@bash scripts/status.sh

doctor: ## Run automated health and connectivity checks
	@bash scripts/doctor.sh

logs: ## Tail logs from all services
	docker compose logs -f

logs-ts: ## Tail Tailscale logs
	docker compose logs -f tailnet-gateway

logs-proxy: ## Tail HTTP proxy logs
	docker compose logs -f http-proxy

logs-privoxy: logs-proxy ## Backward-compatible alias for proxy logs

add-domain: ## Add a private DNS suffix — usage: make add-domain DOMAIN=internal
	@[ -n "$(DOMAIN)" ] || (echo "Usage: make add-domain DOMAIN=internal" && exit 1)
	@bash scripts/add-domain.sh $(DOMAIN)

test: ## Verify proxy is up and public traffic routes direct
	@echo "Testing proxy at http://127.0.0.1:$${PRIVOXY_PORT:-8118}..."
	@curl -x http://127.0.0.1:$${PRIVOXY_PORT:-8118} -sf -o /dev/null \
		-w "HTTP %{http_code} — proxy is up, example.com routed DIRECT\n" http://example.com

clean: ## Remove containers and Tailscale state (requires re-authentication afterward)
	@echo "WARNING: This removes Tailscale auth state. You will need to re-authenticate."
	@read -p "Continue? [y/N] " c && [ "$${c}" = "y" ]
	docker compose down
	rm -f tailscale/state/*
	@echo "Done. Run 'make up && make login' to start fresh."
