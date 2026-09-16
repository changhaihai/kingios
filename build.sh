#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$ROOT"

for tool in xcodegen xcodebuild ldid zip; do
  command -v "$tool" >/dev/null 2>&1 || { echo "missing tool: $tool" >&2; exit 2; }
done

rm -rf build package dist SharedHUD.xcodeproj
mkdir -p build package/Payload dist
xcodegen generate --spec project.yml
xcodebuild \
  -project SharedHUD.xcodeproj \
  -scheme SharedHUD \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

APP=$(find build/Build/Products/Release-iphoneos -maxdepth 1 -name '*.app' -type d | head -n 1)
[ -n "$APP" ] && [ -x "$APP/SharedHUD" ] || { echo "SharedHUD.app was not produced" >&2; exit 3; }
cp -R "$APP" package/Payload/
ldid -SResources/SharedHUD.entitlements package/Payload/SharedHUD.app/SharedHUD
(cd package && zip -qry ../dist/SharedHUD.tipa Payload)
echo "BUILD_OK $ROOT/dist/SharedHUD.tipa"
