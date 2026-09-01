#!/bin/zsh
set -euo pipefail

if ! command -v ollama >/dev/null 2>&1; then
  echo "Ollama is not installed. Install it from https://ollama.com, then run this script again."
  exit 1
fi

ollama pull llama3:8b
echo "NOVA’s free local model is ready. Open outputs/NOVA.app."
