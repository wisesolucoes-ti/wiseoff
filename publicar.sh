#!/usr/bin/env bash
set -euo pipefail

python3 build_static.py
repo_path="$(pwd)"
git -c safe.directory="$repo_path" add .
git -c safe.directory="$repo_path" commit -m "Atualiza ofertas" || true
git -c safe.directory="$repo_path" push origin main

echo "Publicação enviada. Acompanhe o andamento na aba Actions do GitHub."
