#!/bin/bash
#
# Standalone script to build YandexMobileAds + DivKit + VGSL as XCFrameworks.
# No external project required — creates a temporary workspace automatically.
#
# Usage:
#   ./build_frameworks.sh [yandex_mobile_ads_version]
#   ./build_frameworks.sh          # uses version from podspec
#   ./build_frameworks.sh 7.12.3   # explicit version
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"
WORK_DIR=$(mktemp -d)

# Read version from argument or podspec
if [ $# -ge 1 ]; then
  YANDEX_VERSION="$1"
else
  YANDEX_VERSION=$(grep "s.version" "$SCRIPT_DIR/YandexMobileAdsBinary.podspec" | head -1 | sed "s/.*'\(.*\)'/\1/")
fi

echo "Building frameworks for YandexMobileAds $YANDEX_VERSION"
echo "Working directory: $WORK_DIR"

# target_name:product_name (order matters for build deps)
TARGETS=(
  "VGSLFundamentals:VGSLFundamentals"
  "VGSLUI:VGSLUI"
  "VGSLNetworking:VGSLNetworking"
  "VGSL:VGSL"
  "DivKit_LayoutKitInterface:LayoutKitInterface"
  "DivKit_LayoutKit:LayoutKit"
  "DivKit_Serialization:Serialization"
  "DivKit:DivKit"
  "DivKitBinaryCompatibilityFacade:DivKitBinaryCompatibilityFacade"
)

# --- Step 1: Create a temporary iOS project with YandexMobileAds ---

cat > "$WORK_DIR/Podfile" << EOF
platform :ios, '13.0'

target 'Dummy' do
  use_frameworks!
  pod 'YandexMobileAds', '=$YANDEX_VERSION'
end
EOF

# Minimal Xcode project for CocoaPods
mkdir -p "$WORK_DIR/Dummy"
cat > "$WORK_DIR/Dummy/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.dummy.build</string>
  <key>CFBundleExecutable</key>
  <string>Dummy</string>
</dict>
</plist>
EOF

cat > "$WORK_DIR/Dummy.xcodeproj/project.pbxproj" << 'PBXPROJ'
// !$*UTF8*$!
{
  archiveVersion = 1;
  classes = {};
  objectVersion = 56;
  objects = {
    ROOT = { isa = PBXProject; buildConfigurationList = CFGLIST; compatibilityVersion = "Xcode 14.0"; mainGroup = MAIN; targets = (TARGET); };
    MAIN = { isa = PBXGroup; children = (); sourceTree = "<group>"; };
    TARGET = { isa = PBXNativeTarget; buildConfigurationList = TCFGLIST; buildPhases = (); name = Dummy; productName = Dummy; productType = "com.apple.product-type.application"; };
    CFGLIST = { isa = XCConfigurationList; buildConfigurations = (DBG, REL); };
    TCFGLIST = { isa = XCConfigurationList; buildConfigurations = (TDBG, TREL); };
    DBG = { isa = XCBuildConfiguration; buildSettings = { ALWAYS_SEARCH_USER_PATHS = NO; IPHONEOS_DEPLOYMENT_TARGET = 13.0; SDKROOT = iphoneos; }; name = Debug; };
    REL = { isa = XCBuildConfiguration; buildSettings = { ALWAYS_SEARCH_USER_PATHS = NO; IPHONEOS_DEPLOYMENT_TARGET = 13.0; SDKROOT = iphoneos; }; name = Release; };
    TDBG = { isa = XCBuildConfiguration; buildSettings = { INFOPLIST_FILE = Dummy/Info.plist; PRODUCT_BUNDLE_IDENTIFIER = com.dummy.build; PRODUCT_NAME = Dummy; }; name = Debug; };
    TREL = { isa = XCBuildConfiguration; buildSettings = { INFOPLIST_FILE = Dummy/Info.plist; PRODUCT_BUNDLE_IDENTIFIER = com.dummy.build; PRODUCT_NAME = Dummy; }; name = Release; };
  };
  rootObject = ROOT;
}
PBXPROJ

echo "=== Installing YandexMobileAds $YANDEX_VERSION via CocoaPods ==="
cd "$WORK_DIR"
pod install --repo-update 2>&1 | grep -v "^$"

PODS_PROJECT="$WORK_DIR/Pods/Pods.xcodeproj"
BUILD_DIR="$WORK_DIR/.build"

if [ ! -d "$PODS_PROJECT" ]; then
  echo "Error: pod install failed — Pods project not found"
  rm -rf "$WORK_DIR"
  exit 1
fi

# --- Step 2: Build each target for device + simulator ---

create_xcframework_manually() {
  local name="$1"
  local device_fw="$2"
  local sim_fw="$3"
  local output="$4"

  rm -rf "$output"
  mkdir -p "$output/ios-arm64" "$output/ios-arm64_x86_64-simulator"
  cp -R "$device_fw" "$output/ios-arm64/"
  cp -R "$sim_fw" "$output/ios-arm64_x86_64-simulator/"

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

echo ""
echo "=== Building XCFrameworks ==="

for entry in "${TARGETS[@]}"; do
  target="${entry%%:*}"
  product="${entry##*:}"

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
    -quiet 2>&1 | grep -E "^(error:|fatal)" || true

  xcodebuild build \
    -project "$PODS_PROJECT" \
    -target "$target" \
    -sdk iphonesimulator \
    -configuration Release \
    CONFIGURATION_BUILD_DIR="$SIM_DIR" \
    OBJROOT="$BUILD_DIR/obj/simulator" \
    -quiet 2>&1 | grep -E "^(error:|fatal)" || true

  DEVICE_FW="$DEVICE_DIR/$product.framework"
  SIM_FW="$SIM_DIR/$product.framework"

  if [ ! -d "$DEVICE_FW" ]; then
    echo "Error: $DEVICE_FW not found"
    rm -rf "$WORK_DIR"
    exit 1
  fi
  if [ ! -d "$SIM_FW" ]; then
    echo "Error: $SIM_FW not found"
    rm -rf "$WORK_DIR"
    exit 1
  fi

  create_xcframework_manually "$product" "$DEVICE_FW" "$SIM_FW" "$OUTPUT_DIR/$product.xcframework"
done

# Copy pre-built YandexMobileAds.xcframework
echo "--- YandexMobileAds.xcframework (copy) ---"
rm -rf "$OUTPUT_DIR/YandexMobileAds.xcframework"
cp -R "$WORK_DIR/Pods/YandexMobileAds/static/YandexMobileAds.xcframework" "$OUTPUT_DIR/"

# --- Step 3: Cleanup ---
rm -rf "$WORK_DIR"

echo ""
echo "Done! All frameworks for YandexMobileAds $YANDEX_VERSION are in $OUTPUT_DIR"
