#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CLIENT="$ROOT/WFLicenseClient.m"
HEADER="$ROOT/WFLicenseClient.h"
VIEW="$ROOT/WFActivationViewController.m"

grep -q 'WFLicenseStatusDeviceRecovery' "$HEADER"
grep -q 'recovery_required code_retained=1' "$CLIENT"
grep -q 'WFLicenseStatusDeviceRecovery' "$VIEW"

if grep -q '@"device_mismatch", @"device_not_activated"\] containsObject:errorCode' "$CLIENT"; then
    echo "FAIL: device recovery errors must not clear the locally saved code"
    exit 1
fi

grep -q 'SecItemUpdate' "$CLIENT"
if sed -n '/+ (BOOL)saveToKeychain:/,/^}/p' "$CLIENT" | grep -q 'SecItemDelete'; then
    echo "FAIL: Keychain save must not delete the existing value before replacement"
    exit 1
fi

echo "License recovery static test: passed"
