.PHONY: help install install-k3s install-istio verify uninstall

help:
	@echo "Usage:"
	@echo "  make install        Install k3s + Istio (full setup)"
	@echo "  make install-k3s    Install k3s only"
	@echo "  make install-istio  Install Istio only (k3s must be running)"
	@echo "  make verify         Verify cluster and Istio health"
	@echo "  make uninstall      Remove Istio and k3s"

install: install-k3s install-istio

install-k3s:
	bash scripts/install-k3s.sh

install-istio:
	bash scripts/install-istio.sh

verify:
	bash scripts/verify.sh

uninstall:
	bash scripts/uninstall.sh
