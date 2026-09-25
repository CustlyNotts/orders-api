# orders-api: Security by Design demo

The running example from the **Security by Design** talk: a small Node.js
orders service, hardened step by step from a developer's laptop to a running
Kubernetes pod. Every snippet on the slides is a real file here.

> The service is deliberately tiny, with no dependencies and orders kept in
> memory, so the security layers are the interesting part.

## Where each slide lives

| Slide | File |
| --- | --- |
| Threat model: IDOR check | `src/app.js`, `test/app.test.js` |
| Pre-commit hooks | `.pre-commit-config.yaml` |
| The workflow, parts 1 and 2 | `.github/workflows/security.yml` |
| Scanner config and noise control | `trivy.yaml`, `.gitleaks.toml`, `.semgrepignore` |
| Pinning and updates | `renovate.json`, `scripts/pin-digests.sh` |
| Bad vs. good Dockerfile | `insecure-examples/Dockerfile.before` vs. `Dockerfile` |
| Bad vs. good Deployment | `insecure-examples/deployment.before.yaml` vs. `k8s/deployment.yaml` |
| Read-only filesystem with `/tmp` | `k8s/deployment.yaml` |
| NetworkPolicy | `k8s/networkpolicy.yaml` |
| Service accounts and RBAC | `k8s/serviceaccount.yaml`, `k8s/examples/role-read-config.yaml` |
| Pod Security Admission | `k8s/namespace.yaml` |
| Kyverno policies | `k8s/policies/` |

## Prerequisites (macOS)

```bash
brew install trivy pre-commit kind kubectl
```

Plus Docker Desktop (or another Docker engine) and Node.js 22 or newer.

## The demos

Run `make` to list them all. In talk order:

### 1. Tests, including the IDOR check

```bash
make test
```

`test/app.test.js` proves customer `c-1` can't read customer `c-2`'s order.

### 2. A leaked secret, blocked before it leaves the laptop

```bash
make leak-demo
```

Writes a freshly generated fake Stripe key to a file, tries to commit it, and
shows the Gitleaks hook blocking the commit. It cleans up afterwards.

### 3. Scan the repo like CI does

```bash
make scan
```

Trivy checks dependencies, secrets and misconfiguration in the Dockerfile and
Kubernetes manifests. It passes: the only findings are low severity, such as
not setting a CPU limit (a deliberate choice, since CPU limits cause throttling).

To see the pipeline catch problems, delete the `skip-dirs` entry in
`trivy.yaml` and run it again. Trivy then reports the insecure examples:
a secret in `ENV` (critical), a root user, no read-only filesystem, and more.

### 4. Compare the before and after images

```bash
make compare
```

Builds both images and prints size, user and high/critical CVE counts: the
numbers for the "Scan both images and compare" slide. Then try:

```bash
docker history --no-trunc orders-api:before | grep API_KEY   # the baked-in secret
docker run --rm --entrypoint ls orders-api:before -la /app    # .git and friends
docker run --rm --entrypoint sh orders-api:after              # fails: no shell
```

### 5. Kubernetes on a local kind cluster

```bash
make kind-up        # create the cluster
make deploy         # namespace (restricted PSA), service account, app, netpols
make netpol-demo    # gateway gets through, intruder times out
make psa-demo       # the insecure Deployment's pods are refused
make policy-demo    # installs Kyverno; redeploying an image without a digest is denied
make kind-down      # clean up
```

kind's default network plugin enforces NetworkPolicy, so no extra setup is
needed. On other clusters, check that your CNI (Calico, Cilium) enforces it.

## Putting it on GitHub

```bash
git init -b main
git add .
git commit -m "orders-api: Security by Design demo"
gh repo create orders-api --public --source . --push   # or add a remote and push
pre-commit install
```

After the first push:

- **Workflow:** runs on every pull request; pushes to `main` also push the image
  to GitHub Container Registry and sign it with cosign.
- **Gitleaks license:** only for repos owned by an organization. Get a free key
  at gitleaks.io and add it as the `GITLEAKS_LICENSE` secret. Personal repos
  don't need one.
- **Renovate:** install the Renovate GitHub app on the repo. It pins the
  Dockerfile's base images to digests, keeps the action SHAs and pre-commit
  tags current, and waits 3 days before adopting any new release
  (`minimumReleaseAge`), which gives compromised releases time to be caught.
  To pin the base images yourself right away, run `bash scripts/pin-digests.sh`.
- **Signature policy:** in `k8s/policies/verify-image-signature.yaml`, replace
  `OWNER` with your GitHub user or organization.

## Why the actions are pinned by SHA

In March 2026, attackers force-pushed malicious code to 75 of the 76 version
tags of `aquasecurity/trivy-action`. Workflows that referenced a tag ran an
infostealer; workflows pinned to a full commit SHA did not. Every `uses:` in
`.github/workflows/security.yml` is pinned to a SHA, with the version in a
comment so Renovate can update it.
