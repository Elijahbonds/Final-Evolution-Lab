#!/usr/bin/env bash
# Create https://github.com/<you>/final-evolution-lab and push this repo (keeps existing origin).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REPO_SLUG="${FEL_GITHUB_REPO_SLUG:-final-evolution-lab}"
DESCRIPTION="${FEL_GITHUB_DESCRIPTION:-Final Evolution Lab}"
REMOTE_NAME="${FEL_GITHUB_REMOTE_NAME:-fel}"

if ! command -v gh >/dev/null 2>&1; then
  echo "Install GitHub CLI: brew install gh" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Not logged in. Run once: gh auth login" >&2
  exit 1
fi

USER_LOGIN="$(gh api user -q .login)"
REPO_URL="https://github.com/${USER_LOGIN}/${REPO_SLUG}.git"

if git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  echo "Remote '$REMOTE_NAME' already exists: $(git remote get-url "$REMOTE_NAME")"
else
  if gh repo view "$USER_LOGIN/$REPO_SLUG" >/dev/null 2>&1; then
    echo "Repo $USER_LOGIN/$REPO_SLUG already exists on GitHub; adding remote only."
    git remote add "$REMOTE_NAME" "$REPO_URL"
  else
    gh repo create "$REPO_SLUG" \
      --public \
      --description "$DESCRIPTION" \
      --source "$ROOT" \
      --remote "$REMOTE_NAME" \
      --push
    echo "Created and pushed to $REPO_URL"
    exit 0
  fi
fi

git push -u "$REMOTE_NAME" main
echo "Pushed main to $REMOTE_NAME ($REPO_URL)"
