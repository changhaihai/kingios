#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
plutil -lint "$ROOT/Resources/Info.plist" "$ROOT/Resources/SharedHUD.entitlements"
grep -q 'registerWindowWithContextID:atLevel:' "$ROOT/Sources/SHSystemOverlay.m"
grep -q 'subscribe\[==\]' "$ROOT/Sources/SHRoomSocket.m"
grep -q 'gameData##' "$ROOT/Sources/SHRoomSocket.m"
grep -q 'platform-application' "$ROOT/Resources/SharedHUD.entitlements"
echo "VALIDATION_OK"
