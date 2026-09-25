#!/usr/bin/env bash
# Demo: the Gitleaks pre-commit hook blocks a commit that contains a secret.
# The fake key is generated on each run, so nothing secret-looking is ever
# stored in this repo. The script cleans up after itself.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

command -v pre-commit >/dev/null || { echo "Install pre-commit first: brew install pre-commit"; exit 1; }
pre-commit install >/dev/null

file=payment-config.env
echo "STRIPE_SECRET_KEY=sk_live_$(openssl rand -hex 16)" > "$file"
git add -f "$file"

echo "Trying to commit $file ..."
echo
if git commit -q -m "Add payment config"; then
  echo "The commit went through, so the hook isn't running. Undoing it."
  git reset -q --soft HEAD~1
else
  echo
  echo "Blocked by the pre-commit hook: the secret never left this laptop."
fi

git reset -q -- "$file"
rm -f "$file"
