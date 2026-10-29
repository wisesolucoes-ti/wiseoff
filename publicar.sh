#!/usr/bin/env bash
set -euo pipefail

python3 build_static.py
repo_path="$(pwd)"
wiseoff_github_user="${WISEOFF_GITHUB_USER:-wisesolucoes-ti}"

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) não encontrado. Instale-o e autentique a conta ${wiseoff_github_user}." >&2
  exit 1
fi

if ! wiseoff_github_token="$(gh auth token --hostname github.com --user "$wiseoff_github_user" 2>/dev/null)"; then
  echo "A conta ${wiseoff_github_user} não está autenticada no GitHub CLI." >&2
  echo "Execute: gh auth login --hostname github.com" >&2
  exit 1
fi

git -c safe.directory="$repo_path" add .
git -c safe.directory="$repo_path" commit -m "Atualiza ofertas" || true
GH_TOKEN="$wiseoff_github_token" git -c safe.directory="$repo_path" push origin main
unset wiseoff_github_token

echo "Publicação enviada. Acompanhe o andamento na aba Actions do GitHub."
