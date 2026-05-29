.PHONY: help install install-k3s install-istio verify uninstall

ISTIO_VERSION ?= 1.24.0
K3S_VERSION   ?= v1.29.4+k3s1

help:
	@echo "Usage:"
	@echo "  make install                                   Install k3s + Istio (default versions)"
	@echo "  make install ISTIO_VERSION=1.29.2 K3S_VERSION=v1.33.1+k3s1"
	@echo "  make install-k3s    Install k3s only"
	@echo "  make install-istio  Install Istio only (k3s must be running)"
	@echo "  make verify         Verify cluster and Istio health"
	@echo "  make uninstall      Remove Istio and k3s"

install: install-k3s install-istio

install-k3s:
	K3S_VERSION=$(K3S_VERSION) bash scripts/install-k3s.sh

install-istio:
	ISTIO_VERSION=$(ISTIO_VERSION) bash scripts/install-istio.sh

verify:
	bash scripts/verify.sh

uninstall:
	bash scripts/uninstall.sh
