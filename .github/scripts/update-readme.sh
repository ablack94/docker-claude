#!/usr/bin/env bash
# Rewrite the generated "current versions" block in README.md.
# Usage: update-readme.sh STABLE_VERSION LATEST_VERSION [README]
set -euo pipefail

stable="$1"
latest="$2"
readme="${3:-README.md}"
image="${IMAGE:-ghcr.io/ablack94/docker-claude}"

start='<!-- versions:start -->'
end='<!-- versions:end -->'

if ! grep -qF "$start" "$readme" || ! grep -qF "$end" "$readme"; then
  echo "::error::$readme is missing the '$start' / '$end' markers" >&2
  exit 1
fi

block="$(mktemp)"
trap 'rm -f "$block"' EXIT
cat > "$block" <<MD
$start
<!-- This block is updated automatically by .github/workflows/publish.yml. Do not edit it by hand. -->
| Tag | Claude Code version | Pull |
|-----|---------------------|------|
| \`stable\` | [\`$stable\`](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) | \`docker pull $image:stable\` |
| \`latest\` | [\`$latest\`](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) | \`docker pull $image:latest\` |
$end
MD

# Replace everything between (and including) the markers with the new block.
awk -v start="$start" -v end="$end" -v block="$block" '
  $0 == start { while ((getline line < block) > 0) print line; skip = 1; next }
  $0 == end   { skip = 0; next }
  !skip
' "$readme" > "$readme.tmp"
mv "$readme.tmp" "$readme"
