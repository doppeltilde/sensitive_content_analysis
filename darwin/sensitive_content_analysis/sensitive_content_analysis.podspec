#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint sensitive_content_analysis.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'sensitive_content_analysis'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project supporting Sensitive Content Analysis.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  
  s.source_files = 'Sources/sensitive_content_analysis/**/*'
  s.public_header_files = 'Sources/sensitive_content_analysis/**/*.h'
  s.swift_version    = '5.5'

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '12.0'

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' 
  }

  s.resource_bundles = {
    'sensitive_content_analysis_privacy' => ['Resources/PrivacyInfo.xcprivacy']
  }
end