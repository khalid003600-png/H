#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_DIR="$PROJECT_DIR/.github/workflows"
mapfile -t WORKFLOWS < <(find "$WORKFLOW_DIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)

if [ "${#WORKFLOWS[@]}" -ne 1 ]; then
    echo "❌ يجب أن يوجد Workflow بناء واحد فقط، الموجود: ${#WORKFLOWS[@]}"
    printf ' - %s\n' "${WORKFLOWS[@]}"
    exit 1
fi

[ "${WORKFLOWS[0]}" = "$WORKFLOW_DIR/build.yml" ] || {
    echo "❌ Workflow المعتمد يجب أن يكون build.yml"
    exit 1
}

rg -F 'name: Build WolFox 1.8.2' "$WORKFLOW_DIR/build.yml" >/dev/null
rg -F 'pull_request:' "$WORKFLOW_DIR/build.yml" >/dev/null
rg -F 'workflow_dispatch:' "$WORKFLOW_DIR/build.yml" >/dev/null
rg -F 'WOLFOX_PROJECT_KEY' "$WORKFLOW_DIR/build.yml" >/dev/null
rg -F './verify_release_artifacts.sh' "$WORKFLOW_DIR/build.yml" >/dev/null

echo "✅ يوجد مسار بناء واحد موحد لطلبات السحب والدفع والتشغيل اليدوي."
