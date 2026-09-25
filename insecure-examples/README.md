# Insecure examples

The "before" files from the talk, kept so you can build, scan and deploy them
side by side with the hardened versions. They are wrong on purpose.

| File | What's wrong with it |
| --- | --- |
| `Dockerfile.before` | `node:latest` (moving tag, full OS), `COPY . .`, a secret in `ENV`, runs as root |
| `Dockerfile.before.dockerignore` | Lets `.git`, tests and scripts into the image |
| `deployment.before.yaml` | No security context, no limits, default service account with a mounted token |

Gitleaks, Semgrep and Trivy all skip this folder (see `.gitleaks.toml`,
`.semgrepignore` and `trivy.yaml`). To watch the pipeline catch these problems,
delete the skip from one of those files and run the scan again.
