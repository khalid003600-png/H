#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALLOW_FILE="WFRedactedLogger.m"
PATTERN='(^|[^[:alnum:]_])(NSLog|os_log|os_log_with_type|os_log_debug|os_log_info|os_log_error|os_log_fault)[[:space:]]*\('

if [[ "$#" -gt 0 ]]; then
    FILES=("$@")
elif git -C "$ROOT" rev-parse --show-toplevel >/dev/null 2>&1; then
    mapfile -t FILES < <(git -C "$ROOT" diff --cached --name-only --diff-filter=ACMRTUXB -- '*.m' '*.mm' '*.h' '*.c' '*.cc' '*.cpp' '*.swift')
else
    mapfile -t FILES < <(find "$ROOT" -type f \( -name '*.m' -o -name '*.mm' -o -name '*.h' -o -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.swift' \) ! -path '*/.wolfox-build/*' ! -path '*/vendor/*' | sort)
fi

violations=0
scanned=0
for file in "${FILES[@]}"; do
    [[ -z "$file" ]] && continue
    if [[ "$file" != /* ]]; then file="$ROOT/$file"; fi
    [[ -f "$file" ]] || continue
    case "$(basename "$file")" in
        "$ALLOW_FILE") continue ;;
    esac
    scanned=$((scanned + 1))
    if matches=$(grep -nE "$PATTERN" "$file" 2>/dev/null); then
        printf 'SECURE-LOGGING violation: %s\n%s\n' "$file" "$matches" >&2
        violations=$((violations + 1))
    fi
done

if [[ "$violations" -ne 0 ]]; then
    echo "رفض الفحص: مرّر السجل عبر WFRedactedLogger/WFLogEvent بدل NSLog أو os_log المباشر." >&2
    exit 1
fi

echo "Secure logging check passed: scanned $scanned source files; direct NSLog/os_log usage not found."
