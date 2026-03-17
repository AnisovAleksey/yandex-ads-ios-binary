# YandexMobileAdsBinary

Prebuilt binary distribution of YandexMobileAds SDK and its transitive dependencies (DivKit, VGSL).
Eliminates ~1000+ Swift files from compiling on every build in consumer projects.

## Project structure

- `Frameworks/` — built XCFrameworks (tracked via Git LFS)
- `sample/` — minimal Xcode project used by the build script to resolve CocoaPods dependencies
- `build_frameworks.sh` — standalone build script that auto-discovers and builds all pod targets
- `YandexMobileAdsBinary.podspec` — CocoaPods podspec (version and frameworks list auto-updated by script)
- `.github/workflows/build.yml` — GitHub Actions workflow for automated builds

## Build script

```bash
./build_frameworks.sh              # latest YandexMobileAds
./build_frameworks.sh 7.12.3       # pin specific version
```

The script:
1. Writes a Podfile in `sample/` and runs `pod install`
2. Auto-discovers all pod targets (skips AppMetrica, KSCrash, YandexMobileAds itself)
3. Builds each target for device (arm64) and simulator (arm64 + x86_64) with dSYMs
4. Creates XCFrameworks manually (directory structure + Info.plist) — `BUILD_LIBRARY_FOR_DISTRIBUTION=YES` is incompatible with VGSL
5. Copies pre-built YandexMobileAds.xcframework from Pods
6. Updates podspec version and `vendored_frameworks` list

## Key decisions

- **Manual XCFramework creation** instead of `xcodebuild -create-xcframework`: VGSL uses `@inlinable`/`@_fixed_layout` which break with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`, and without it there are no `.swiftinterface` files for `-create-xcframework`
- **AppMetrica stays as CocoaPods source dependency**: shared with `appmetrica_plugin` in consumer projects, avoids version conflicts
- **Git LFS**: all files under `Frameworks/` are tracked via LFS (~509 MB total)
- **Target name ≠ product name**: e.g. `DivKit_LayoutKit` produces `LayoutKit.framework` — script queries `PRODUCT_MODULE_NAME` from build settings

## Usage in consumer projects

```ruby
pod 'YandexMobileAdsBinary', :git => 'https://github.com/AnisovAleksey/yandex-ads-ios-binary.git', :tag => '7.12.3'
```
