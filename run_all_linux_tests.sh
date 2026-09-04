#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

run_test() {
    local test_file="$1"
    if [ -x "$PROJECT_DIR/$test_file" ]; then
        echo "=== $test_file ==="
        "$PROJECT_DIR/$test_file"
    else
        echo "ℹ️  تم تخطي $test_file: الملف غير موجود في مصدر Full الحالي."
    fi
}

run_test "test_build_compatibility_static.sh"
run_test "test_repository_safety_static.sh"
run_test "test_location_hooks_static.sh"
run_test "test_schedule_static.sh"
run_test "test_license_recovery_static.sh"
run_test "test_identifier_hooks_static.sh"
run_test "test_virtual_camera_static.sh"
run_test "test_persistent_state_safety_static.sh"
run_test "run_linux_virtual_camera_tests.sh"
run_test "run_linux_identifier_tests.sh"
run_test "run_linux_location_tests.sh"

echo "✅ اكتملت اختبارات WolFox المتاحة على لينكس."
