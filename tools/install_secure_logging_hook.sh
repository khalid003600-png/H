#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$ROOT/.githooks"
HOOK="$HOOKS_DIR/pre-commit"
mkdir -p "$HOOKS_DIR"

cat > "$HOOK" <<'HOOK_EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
exec "$ROOT/tools/check_secure_logging.sh"
HOOK_EOF

chmod +x "$ROOT/tools/check_secure_logging.sh" "$HOOK"
if git -C "$ROOT" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "$ROOT" config core.hooksPath .githooks
    echo "Installed secure logging pre-commit hook in $ROOT"
else
    echo "No Git repository found at $ROOT. Copy .githooks and tools into the repository root, then run this installer there." >&2
    exit 2
fi
