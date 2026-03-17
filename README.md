# YandexMobileAdsBinary

Prebuilt binary distribution of [YandexMobileAds](https://yandex.ru/dev/mobile-ads/) SDK and its transitive dependencies (DivKit, VGSL). Eliminates ~1000+ Swift files from compiling on every build.

## Installation

Add to your `Podfile`:

```ruby
pod 'YandexMobileAdsBinary', :git => 'https://github.com/AnisovAleksey/yandex-ads-ios-binary.git', :tag => '7.12.3'
```

Then run:

```bash
pod install
```

AppMetrica dependencies are resolved via CocoaPods automatically.

## Updating to a new version

### Via GitHub Actions (recommended)

1. Go to **Actions** → **Build and Release**
2. Click **Run workflow**
3. Enter the YandexMobileAds version (or leave empty for latest)
4. The workflow builds all frameworks, updates the podspec, commits and tags

### Manually

```bash
./build_frameworks.sh 7.13.0
```

The script will:
- Install YandexMobileAds in the `sample/` project
- Auto-discover all transitive dependencies
- Build each as XCFramework with dSYMs
- Update `YandexMobileAdsBinary.podspec` version and frameworks list

Then commit, tag and push:

```bash
git add -A
git commit -m "Update YandexMobileAds to 7.13.0"
git tag 7.13.0
git push origin main --tags
```

## How it works

The `sample/` directory contains a minimal Xcode project with a `Podfile` that depends on `YandexMobileAds`. The build script:

1. Runs `pod install` in `sample/` to resolve all dependencies
2. Discovers all pod targets except AppMetrica (kept as CocoaPods source dep)
3. Builds each target for device (arm64) and simulator (arm64 + x86_64)
4. Packages them into XCFrameworks with dSYM debug symbols
5. Updates the podspec with the resolved version and frameworks list
