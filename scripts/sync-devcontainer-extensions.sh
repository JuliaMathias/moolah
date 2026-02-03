#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REPO_ROOT="$repo_root" python3 - <<'PY'
import json
from pathlib import Path
import os

repo_root = Path(os.environ["REPO_ROOT"])

extensions_path = repo_root / ".vscode" / "extensions.json"
container_path = repo_root / ".devcontainer" / "devcontainer.json"

extensions_data = json.loads(extensions_path.read_text())
extensions = extensions_data.get("recommendations", [])

container_data = json.loads(container_path.read_text())
container_data.setdefault("customizations", {}).setdefault("vscode", {})
container_data["customizations"]["vscode"]["extensions"] = extensions

container_path.write_text(json.dumps(container_data, indent=2) + "\n")
PY

echo "Updated .devcontainer/devcontainer.json from .vscode/extensions.json"
