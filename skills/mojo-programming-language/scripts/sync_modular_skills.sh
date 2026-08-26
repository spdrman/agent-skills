#!/usr/bin/env bash
set -euo pipefail

BASE="https://raw.githubusercontent.com/modular/skills/main"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${ROOT}/references/modular-official/upstream"

mkdir -p "${DEST}/mojo-syntax" \
         "${DEST}/mojo-gpu-fundamentals" \
         "${DEST}/mojo-python-interop" \
         "${DEST}/new-modular-project" \
         "${DEST}/closure_migration"

fetch() {
  local url="$1"
  local out="$2"
  echo "Fetching ${url}"
  curl --fail --location --silent --show-error "${url}" -o "${out}"
}

fetch "${BASE}/mojo-syntax/SKILL.md" \
      "${DEST}/mojo-syntax/SKILL.md"
fetch "${BASE}/mojo-gpu-fundamentals/SKILL.md" \
      "${DEST}/mojo-gpu-fundamentals/SKILL.md"
fetch "${BASE}/mojo-python-interop/SKILL.md" \
      "${DEST}/mojo-python-interop/SKILL.md"
fetch "${BASE}/new-modular-project/SKILL.md" \
      "${DEST}/new-modular-project/SKILL.md"
fetch "${BASE}/closure_migration/SKILL.md" \
      "${DEST}/closure_migration/SKILL.md"
fetch "${BASE}/closure_migration/process.md" \
      "${DEST}/closure_migration/process.md"
fetch "${BASE}/LICENSE" \
      "${DEST}/LICENSE"

cat > "${DEST}/SNAPSHOT.txt" <<EOF
Source: https://github.com/modular/skills
Branch: main
Fetched: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "Upstream Modular Mojo resources refreshed in: ${DEST}"
