#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
QA_DIR=$(mktemp -d "${TMPDIR:-/tmp}/schon-provider-isolation.XXXXXX")
trap 'rm -rf "$QA_DIR"' EXIT
xcrun swiftc -emit-module -emit-library -module-name StoreKit Tests/ProviderIsolation/StoreKitStub.swift -o "$QA_DIR/libStoreKit.dylib" -emit-module-path "$QA_DIR/StoreKit.swiftmodule"
xcrun swiftc -DDEBUG -I "$QA_DIR" -L "$QA_DIR" -lStoreKit -parse-as-library SchonErledigt/Services/PurchaseManager.swift Tests/ProviderIsolation/Smoke.swift -o "$QA_DIR/smoke"
DYLD_LIBRARY_PATH="$QA_DIR" "$QA_DIR/smoke" --schonProviderDisabledQA

EXPECT_PROVIDER_CALLS=1 DYLD_LIBRARY_PATH="$QA_DIR" "$QA_DIR/smoke"
xcrun swiftc -I "$QA_DIR" -L "$QA_DIR" -lStoreKit -parse-as-library SchonErledigt/Services/PurchaseManager.swift Tests/ProviderIsolation/Smoke.swift -o "$QA_DIR/release-smoke"
EXPECT_PROVIDER_CALLS=1 DYLD_LIBRARY_PATH="$QA_DIR" "$QA_DIR/release-smoke" --schonProviderDisabledQA
