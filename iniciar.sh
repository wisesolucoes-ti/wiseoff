#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Erro: Python 3 não foi encontrado."
  exit 1
fi

cd "$SCRIPT_DIR"

echo "Iniciando o painel WiseOff..."
echo "Cadastro: http://127.0.0.1:8000/admin.html"
echo "Para encerrar, pressione Ctrl+C."

exec python3 server.py
