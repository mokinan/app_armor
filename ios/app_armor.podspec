#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint app_armor.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'app_armor'
  s.version          = '0.1.0'
  s.summary          = 'All-in-one mobile security for Flutter apps.'
  s.description      = <<-DESC
Runtime protection, screen privacy and secure storage for Flutter apps.
                       DESC
  s.homepage         = 'https://github.com/mokinan/app_armor'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Mohamed Kinan' => 'mohamed.kinan3@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'app_armor/Sources/app_armor/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = {'app_armor_privacy' => ['app_armor/Sources/app_armor/PrivacyInfo.xcprivacy']}
end
