// import 'package:flutter_test/flutter_test.dart';
// import 'package:sensitive_content_analysis/sensitive_content_analysis.dart';
// import 'package:sensitive_content_analysis/sensitive_content_analysis_platform_interface.dart';
// import 'package:sensitive_content_analysis/sensitive_content_analysis_method_channel.dart';
// import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// class MockSensitiveContentAnalysisPlatform
//     with MockPlatformInterfaceMixin
//     implements SensitiveContentAnalysisPlatform {

//   @override
//   Future<String?> getPlatformVersion() => Future.value('42');
// }

// void main() {
//   final SensitiveContentAnalysisPlatform initialPlatform = SensitiveContentAnalysisPlatform.instance;

//   test('$MethodChannelSensitiveContentAnalysis is the default instance', () {
//     expect(initialPlatform, isInstanceOf<MethodChannelSensitiveContentAnalysis>());
//   });

//   test('getPlatformVersion', () async {
//     SensitiveContentAnalysis sensitiveContentAnalysisPlugin = SensitiveContentAnalysis();
//     MockSensitiveContentAnalysisPlatform fakePlatform = MockSensitiveContentAnalysisPlatform();
//     SensitiveContentAnalysisPlatform.instance = fakePlatform;

//     expect(await sensitiveContentAnalysisPlugin.getPlatformVersion(), '42');
//   });
// }
