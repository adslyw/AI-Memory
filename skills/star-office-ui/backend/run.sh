#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PYTHON="/home/deepnight/.openclaw-venv/bin/python3"

cd "$ROOT_DIR/backend"
exec "$VENV_PYTHON" -c "
import os, sys
sys.path.insert(0, '$ROOT_DIR')
from app import app
print('=' * 50)
print('Star Office UI')
print('=' * 50)
print('Starting on http://127.0.0.1:19500')
print('Press Ctrl+C to stop')
print('')
app.run(host='127.0.0.1', port=19500, debug=False, use_reloader=False)
"
