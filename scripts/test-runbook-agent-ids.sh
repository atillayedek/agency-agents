#!/usr/bin/env bash
# Regression for #1027: roster ids must match the converter, not file stems.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/repo/scripts" "$scratch/repo/engineering" "$scratch/repo/strategy"
cp "$SCRIPT_DIR/check-runbooks.sh" "$SCRIPT_DIR/lib.sh" "$scratch/repo/scripts/"
printf '%s\n' '{"divisions":{"engineering":{}}}' > "$scratch/repo/divisions.json"
printf '%s\n' '---' "name: 'Senior Project Manager'" 'description: Fixture' '---' '# Agent' > "$scratch/repo/engineering/project-manager-senior.md"
printf '%s\n' '# Runbook' > "$scratch/repo/strategy/scenario.md"
cd "$scratch/repo"
git init -q
git add engineering/project-manager-senior.md
python3 - <<'PY'
import json
runbook = {"slug": "fixture", "title": "Fixture", "mode": "NEXUS-Sprint", "doc": "strategy/scenario.md", "roster": [{"group": "Core", "agents": ["senior-project-manager"]}]}
with open('strategy/runbooks.json', 'w') as f:
    json.dump({"runbooks": [runbook]}, f)
PY
bash scripts/check-runbooks.sh
python3 - <<'PY'
import json
with open('strategy/runbooks.json') as f:
    data = json.load(f)
data['runbooks'][0]['roster'][0]['agents'] = ['project-manager-senior']
with open('strategy/runbooks.json', 'w') as f:
    json.dump(data, f)
PY
if bash scripts/check-runbooks.sh > "$scratch/log" 2>&1; then
  echo 'FAIL: checker accepted a filename stem instead of a rendered id' >&2
  exit 1
fi
grep -q "slug 'project-manager-senior' does not match any rendered agent id" "$scratch/log"
echo 'PASS: rendered ids accepted and legacy filename stems rejected'
