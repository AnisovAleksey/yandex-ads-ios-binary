#!/bin/bash
#
# Builds YandexMobileAds and all its transitive dependencies as XCFrameworks.
# Uses the sample/ project — no external project required.
#
# Automatically discovers all pod targets (except AppMetrica, which stays as
# a CocoaPods source dependency) and builds them with dSYMs.
#
# Usage:
#   ./build_frameworks.sh              # latest YandexMobileAds
#   ./build_frameworks.sh 7.12.3       # pin specific version
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAMPLE_DIR="$SCRIPT_DIR/sample"
OUTPUT_DIR="$SCRIPT_DIR/Frameworks"
BUILD_DIR="$SAMPLE_DIR/.build"

# --- Step 0: Resolve version ---

if [ $# -ge 1 ]; then
  YANDEX_VERSION="=$1"
  VERSION_LABEL="$1"
else
  YANDEX_VERSION=""
  VERSION_LABEL="latest"
fi

echo "Building frameworks for YandexMobileAds $VERSION_LABEL"

# --- Step 1: pod install in sample project ---

cd "$SAMPLE_DIR"

# Write Podfile with requested version
if [ -n "$YANDEX_VERSION" ]; then
  cat > "$SAMPLE_DIR/Podfile" << EOF
platform :ios, '13.0'

target 'Dummy' do
  use_frameworks!
  pod 'YandexMobileAds', '$YANDEX_VERSION'
end
EOF
else
  cat > "$SAMPLE_DIR/Podfile" << EOF
platform :ios, '13.0'

target 'Dummy' do
  use_frameworks!
  pod 'YandexMobileAds'
end
EOF
fi

pod install --repo-update 2>&1 | grep -v "^$"

PODS_PROJECT="$SAMPLE_DIR/Pods/Pods.xcodeproj"
if [ ! -d "$PODS_PROJECT" ]; then
  echo "Error: pod install failed"
  exit 1
fi

# Extract actual resolved version
YANDEX_RESOLVED=$(grep 'YandexMobileAds (' "$SAMPLE_DIR/Podfile.lock" | head -1 | sed 's/.*(\(.*\)).*/\1/')
echo "Resolved YandexMobileAds version: $YANDEX_RESOLVED"

# --- Step 2: Discover pod targets to build ---
# We build everything except: AppMetrica*, KSCrash*, Dummy (the app target), and Pods-* aggregates.
# These are either managed by CocoaPods separately or are not real frameworks.

# YandexMobileAds is already a pre-built xcframework — just copy it, don't build
SKIP_PATTERN="^(AppMetrica|KSCrash|Dummy|Pods-|YandexMobileAds|.*PrivacyInfo)"

ALL_TARGETS=$(xcodebuild -project "$PODS_PROJECT" -list 2>/dev/null \
  | sed -n '/Targets:/,/Build Configurations:/p' \
  | grep -v "Targets:\|Build Configurations:" \
  | sed 's/^[[:space:]]*//' \
  | grep -v "^$" \
  | sort -u)

echo ""
echo "=== Discovered pod targets ==="

TARGETS_TO_BUILD=()
for target in $ALL_TARGETS; do
  if echo "$target" | grep -qE "$SKIP_PATTERN"; then
    continue
  fi
  TARGETS_TO_BUILD+=("$target")
  echo "  $target"
done

echo ""

# --- Step 3: Build each target ---

rm -rf "$BUILD_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

create_xcframework() {
  local name="$1"
  local device_fw="$2"
  local sim_fw="$3"
  local output="$4"
  local device_dsym="$5"
  local sim_dsym="$6"

  rm -rf "$output"
  mkdir -p "$output/ios-arm64" "$output/ios-arm64_x86_64-simulator"
  cp -R "$device_fw" "$output/ios-arm64/"
  cp -R "$sim_fw" "$output/ios-arm64_x86_64-simulator/"

  # Include dSYMs if available
  if [ -d "$device_dsym" ]; then
    cp -R "$device_dsym" "$output/ios-arm64/"
  fi
  if [ -d "$sim_dsym" ]; then
    cp -R "$sim_dsym" "$output/ios-arm64_x86_64-simulator/"
  fi

  cat > "$output/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>AvailableLibraries</key>
  <array>
    <dict>
      <key>BinaryPath</key>
      <string>${name}.framework/${name}</string>
      <key>LibraryIdentifier</key>
      <string>ios-arm64</string>
      <key>LibraryPath</key>
      <string>${name}.framework</string>
      <key>SupportedArchitectures</key>
      <array>
        <string>arm64</string>
      </array>
      <key>SupportedPlatform</key>
      <string>ios</string>
    </dict>
    <dict>
      <key>BinaryPath</key>
      <string>${name}.framework/${name}</string>
      <key>LibraryIdentifier</key>
      <string>ios-arm64_x86_64-simulator</string>
      <key>LibraryPath</key>
      <string>${name}.framework</string>
      <key>SupportedArchitectures</key>
      <array>
        <string>arm64</string>
        <string>x86_64</string>
      </array>
      <key>SupportedPlatform</key>
      <string>ios</string>
      <key>SupportedPlatformVariant</key>
      <string>simulator</string>
    </dict>
  </array>
  <key>CFBundlePackageType</key>
  <string>XFWK</string>
  <key>XCFrameworkFormatVersion</key>
  <string>1.0</string>
</dict>
</plist>
PLIST
}

echo "=== Building XCFrameworks ==="

for target in "${TARGETS_TO_BUILD[@]}"; do
  # Get the actual product name (may differ from target name)
  product=$(xcodebuild -project "$PODS_PROJECT" -target "$target" -showBuildSettings 2>/dev/null \
    | grep "PRODUCT_MODULE_NAME" | head -1 | awk '{print $3}')
  if [ -z "$product" ]; then
    product="$target"
  fi

  echo "--- $target -> $product.xcframework ---"

  DEVICE_DIR="$BUILD_DIR/device/$target"
  SIM_DIR="$BUILD_DIR/simulator/$target"
  mkdir -p "$DEVICE_DIR" "$SIM_DIR"

  xcodebuild build \
    -project "$PODS_PROJECT" \
    -target "$target" \
    -sdk iphoneos \
    -configuration Release \
    CONFIGURATION_BUILD_DIR="$DEVICE_DIR" \
    OBJROOT="$BUILD_DIR/obj/device" \
    DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
    -quiet 2>&1 | grep -E "^(error:|fatal)" || true

  xcodebuild build \
    -project "$PODS_PROJECT" \
    -target "$target" \
    -sdk iphonesimulator \
    -configuration Release \
    CONFIGURATION_BUILD_DIR="$SIM_DIR" \
    OBJROOT="$BUILD_DIR/obj/simulator" \
    DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
    -quiet 2>&1 | grep -E "^(error:|fatal)" || true

  DEVICE_FW="$DEVICE_DIR/$product.framework"
  SIM_FW="$SIM_DIR/$product.framework"
  DEVICE_DSYM="$DEVICE_DIR/$product.framework.dSYM"
  SIM_DSYM="$SIM_DIR/$product.framework.dSYM"

  if [ ! -d "$DEVICE_FW" ]; then
    echo "Warning: $product.framework not found for device, skipping $target"
    continue
  fi
  if [ ! -d "$SIM_FW" ]; then
    echo "Warning: $product.framework not found for simulator, skipping $target"
    continue
  fi

  create_xcframework "$product" "$DEVICE_FW" "$SIM_FW" "$OUTPUT_DIR/$product.xcframework" "$DEVICE_DSYM" "$SIM_DSYM"
done

# Copy pre-built YandexMobileAds.xcframework (already binary from Yandex)
echo "--- YandexMobileAds.xcframework (copy) ---"
cp -R "$SAMPLE_DIR/Pods/YandexMobileAds/static/YandexMobileAds.xcframework" "$OUTPUT_DIR/"

# --- Step 4: Cleanup ---
rm -rf "$BUILD_DIR"

# --- Step 5: Update podspec version ---
sed -i '' "s/s.version.*=.*/s.version      = '$YANDEX_RESOLVED'/" "$SCRIPT_DIR/YandexMobileAdsBinary.podspec"

# Update vendored_frameworks list dynamically
FRAMEWORKS=$(ls -d "$OUTPUT_DIR"/*.xcframework | xargs -I{} basename {} | sort)
VENDOR_LIST=""
for fw in $FRAMEWORKS; do
  VENDOR_LIST="$VENDOR_LIST    'Frameworks/$fw',\n"
done

# Replace vendored_frameworks block in podspec
python3 -c "
import re, sys
with open('$SCRIPT_DIR/YandexMobileAdsBinary.podspec') as f:
    content = f.read()
new_list = '''$VENDOR_LIST'''
content = re.sub(
    r\"s\.vendored_frameworks\s*=\s*\[.*?\]\",
    's.vendored_frameworks = [\n' + new_list.rstrip(',\n') + '\n  ]',
    content, flags=re.DOTALL)
with open('$SCRIPT_DIR/YandexMobileAdsBinary.podspec', 'w') as f:
    f.write(content)
"

echo ""
echo "Done! YandexMobileAds $YANDEX_RESOLVED"
echo "Frameworks in $OUTPUT_DIR:"
ls "$OUTPUT_DIR/" | grep xcframework
echo ""
echo "Podspec updated to version $YANDEX_RESOLVED"
