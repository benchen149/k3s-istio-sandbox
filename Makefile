.PHONY: help install install-k3s install-istio verify uninstall uninstall-istio uninstall-k3s

ISTIO_VERSION ?= 1.24.0

help:
	@echo "Usage:"
	@echo "  make install                             Install k3s + Istio (Istio 1.24.0, k3s auto-matched)"
	@echo "  make install ISTIO_VERSION=1.29.2        Auto-select compatible k3s version"
	@echo "  make install ISTIO_VERSION=1.29.2 K3S_VERSION=v1.33.0+k3s1  Override k3s manually"
	@echo "  make install-k3s    Install k3s only"
	@echo "  make install-istio  Install Istio only (k3s must be running)"
	@echo "  make verify            Verify cluster and Istio health"
	@echo "  make uninstall         Remove Istio and k3s"
	@echo "  make uninstall-istio   Remove Istio only"
	@echo "  make uninstall-k3s     Remove k3s only"

install: install-k3s install-istio

install-k3s:
	ISTIO_VERSION=$(ISTIO_VERSION) K3S_VERSION=$(K3S_VERSION) bash scripts/install-k3s.sh

install-istio:
	ISTIO_VERSION=$(ISTIO_VERSION) bash scripts/install-istio.sh

verify:
	bash scripts/verify.sh

uninstall: uninstall-istio uninstall-k3s

uninstall-istio:
	ISTIO_VERSION=$(ISTIO_VERSION) bash scripts/uninstall-istio.sh

uninstall-k3s:
	bash scripts/uninstall-k3s.sh
