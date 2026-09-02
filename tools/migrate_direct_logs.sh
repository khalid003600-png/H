#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for file in "$ROOT"/*.m "$ROOT"/*.mm; do
    [[ -f "$file" ]] || continue
    [[ "$(basename "$file")" == "WFRedactedLogger.m" ]] && continue
    if grep -q 'NSLog[[:space:]]*(' "$file"; then
        sed -i 's/\<NSLog[[:space:]]*(/WFLog(/g' "$file"
        if ! grep -q '^#import "WFRedactedLogger.h"' "$file"; then
            sed -i '1i#import "WFRedactedLogger.h"' "$file"
        fi
    fi
done
