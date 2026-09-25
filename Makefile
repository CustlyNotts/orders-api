# Shortcuts for the demos in the talk. Run `make help` for the list.
CLUSTER ?= security-demo
KYVERNO_VERSION ?= v1.19.1

.DEFAULT_GOAL := help
.PHONY: help test run build build-before compare scan leak-demo kind-up kind-load deploy netpol-demo psa-demo policy-demo kind-down

help: ## Show the available demos
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  make %-14s %s\n", $$1, $$2}'

test: ## Run the unit tests (including the IDOR test)
	npm test

run: ## Run the API locally on :3000
	npm start

build: ## Build the hardened image (orders-api:after)
	docker build -t orders-api:after .

build-before: ## Build the insecure image (orders-api:before)
	docker build -f insecure-examples/Dockerfile.before -t orders-api:before .

compare: ## Size, user and CVE counts for both images (the comparison slide)
	bash scripts/compare-images.sh

scan: ## Trivy scan of the repo: dependencies, secrets, misconfig
	trivy fs --config trivy.yaml .

leak-demo: ## Watch the pre-commit hook block a leaked secret
	bash scripts/leak-a-secret.sh

kind-up: ## Create a local kind cluster
	kind create cluster --name $(CLUSTER)

kind-load: build build-before ## Load both images into the kind cluster
	kind load docker-image orders-api:after orders-api:before --name $(CLUSTER)

deploy: kind-load ## Deploy the hardened app (namespace, PSA, netpols)
	kubectl apply -k k8s
	kubectl -n orders rollout status deployment/orders-api --timeout=120s

netpol-demo: ## Gateway can reach orders-api; intruder can't
	kubectl apply -f k8s/demo/clients.yaml
	kubectl -n orders wait --for=condition=Ready pod/gateway pod/intruder --timeout=120s
	@echo "--- from gateway (allowed):"
	kubectl -n orders exec gateway -- curl -sS -m 5 http://orders-api/healthz
	@echo
	@echo "--- from intruder (should time out):"
	@kubectl -n orders exec intruder -- curl -sS -m 5 http://orders-api/healthz 2>&1 || echo "=> blocked by NetworkPolicy, as expected"

psa-demo: ## Pod Security Admission refuses the insecure Deployment
	kubectl apply -f insecure-examples/deployment.before.yaml
	@sleep 3
	kubectl -n orders get events --field-selector reason=FailedCreate
	kubectl -n orders delete -f insecure-examples/deployment.before.yaml --ignore-not-found

policy-demo: ## Install Kyverno and reject images not pinned by digest
	kubectl get namespace kyverno >/dev/null 2>&1 || kubectl create -f https://github.com/kyverno/kyverno/releases/download/$(KYVERNO_VERSION)/install.yaml
	kubectl -n kyverno wait --for=condition=Available deployment --all --timeout=300s
	@echo "Waiting for Kyverno's webhook to accept requests..."
	@for i in $$(seq 1 24); do kubectl apply -f k8s/policies/require-image-digest.yaml 2>/dev/null && break; sleep 5; done
	kubectl wait --for=condition=Ready clusterpolicy/require-image-digest --timeout=120s
	@sleep 5
	@echo "--- redeploying orders-api:after (tag, no digest), which should be denied:"
	-kubectl -n orders rollout restart deployment/orders-api

kind-down: ## Delete the kind cluster
	kind delete cluster --name $(CLUSTER)

