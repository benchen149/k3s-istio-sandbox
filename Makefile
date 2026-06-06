.PHONY: help install install-k3s install-istio status verify verify-samples clean-samples uninstall uninstall-istio uninstall-k3s serve serve-stop test

ISTIO_VERSION ?= 1.24.0

help:
	@echo "Usage:"
	@echo "  make install                             Install k3s + Istio (Istio 1.24.0, k3s auto-matched)"
	@echo "  make install ISTIO_VERSION=1.29.2        Auto-select compatible k3s version"
	@echo "  make install ISTIO_VERSION=1.29.2 K3S_VERSION=v1.33.0+k3s1  Override k3s manually"
	@echo "  make install-k3s    Install k3s only"
	@echo "  make install-istio  Install Istio only (k3s must be running)"
	@echo "  make status            Show k3s cluster status (active / inactive / not-found)"
	@echo "  make verify            Verify cluster and Istio health"
	@echo "  make verify-samples    Smoke test: deploy nginx + ingress, assert HTTP 200 (resources kept)"
	@echo "  make clean-samples     Remove resources left by verify-samples"
	@echo "  make uninstall         Remove Istio and k3s"
	@echo "  make uninstall-istio   Remove Istio only"
	@echo "  make uninstall-k3s     Remove k3s only"
	@echo "  make serve             Start Slack webhook server (requires .env)"
	@echo "  make serve-stop        Stop Slack webhook server"
	@echo "  make test              Run all tests"

install: install-k3s install-istio verify-samples

install-k3s:
	sudo -n --preserve-env=ISTIO_VERSION,K3S_VERSION /usr/bin/bash $(CURDIR)/scripts/install-k3s.sh

install-istio:
	ISTIO_VERSION=$(ISTIO_VERSION) bash scripts/install-istio.sh

status:
	@bash scripts/status.sh

verify:
	bash scripts/verify.sh

verify-samples:
	ISTIO_VERSION=$(ISTIO_VERSION) bash scripts/verify-samples.sh

clean-samples:
	kubectl delete -f samples/02-ingress/gateway-virtualservice.yaml --ignore-not-found
	kubectl delete -f samples/01-deploy/nginx.yaml --ignore-not-found
	kubectl label namespace default istio-injection- --overwrite 2>/dev/null || true

uninstall: uninstall-istio uninstall-k3s

uninstall-istio:
	ISTIO_VERSION=$(ISTIO_VERSION) bash scripts/uninstall-istio.sh

uninstall-k3s:
	sudo -n /usr/bin/bash $(CURDIR)/scripts/uninstall-k3s.sh

serve:
	@[ -f .env ] || (echo "Error: .env not found. Copy .env.example and fill in values." && exit 1)
	nohup python3 scripts/slack_webhook.py > /tmp/slack-webhook.log 2>&1 & echo $$! > /tmp/slack-webhook.pid
	@echo "Webhook server started (PID $$(cat /tmp/slack-webhook.pid)). Log: /tmp/slack-webhook.log"

serve-stop:
	@[ -f /tmp/slack-webhook.pid ] && kill $$(cat /tmp/slack-webhook.pid) && rm /tmp/slack-webhook.pid && echo "Server stopped" || echo "Server not running"

test:
	python3 -m pytest tests/ -v

