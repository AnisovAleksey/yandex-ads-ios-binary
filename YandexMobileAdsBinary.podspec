Pod::Spec.new do |s|
  s.name         = 'YandexMobileAdsBinary'
  s.version      = '7.12.3'
  s.summary      = 'Prebuilt YandexMobileAds with DivKit and VGSL dependencies'
  s.description  = 'Binary distribution of YandexMobileAds SDK and its transitive dependencies (DivKit, VGSL) to avoid recompilation from source on every build.'
  s.homepage     = 'https://github.com/AnisovAleksey/yandex-ads-ios-binary'
  s.license      = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.author       = { 'Aleksei Anisov' => 'threat70@gmail.com' }
  s.source       = { :git => 'https://github.com/AnisovAleksey/yandex-ads-ios-binary.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.static_framework = true

  s.vendored_frameworks = [
    'YandexMobileAds.xcframework',
    'DivKit.xcframework',
    'DivKitBinaryCompatibilityFacade.xcframework',
    'LayoutKit.xcframework',
    'LayoutKitInterface.xcframework',
    'Serialization.xcframework',
    'VGSL.xcframework',
    'VGSLFundamentals.xcframework',
    'VGSLNetworking.xcframework',
    'VGSLUI.xcframework',
  ]

  s.dependency 'AppMetricaCore', '>= 5.8.0', '< 6.0.0'
  s.dependency 'AppMetricaCrashes', '>= 5.8.0', '< 6.0.0'
  s.dependency 'AppMetricaLibraryAdapter', '>= 5.8.0', '< 6.0.0'
end
