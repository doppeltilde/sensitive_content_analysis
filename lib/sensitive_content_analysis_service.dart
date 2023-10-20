import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensitive_content_analysis/sensitive_content_analysis.dart';

const methodChannel = MethodChannel('sensitive_content_analysis');

class SensitiveContentAnalysisService extends SensitiveContentAnalysis {
  @override
  Future<bool> analyzeImage(Uint8List file) async {
    try {
      final dynamic isSensitive =
          await methodChannel.invokeMethod('analyzeImage', file);
      return isSensitive;
    } on PlatformException catch (e) {
      debugPrint(e.toString());
      return false;
    }
  }

  @override
  Future<void> intervene(String path) async {
    await methodChannel.invokeMethod('intervene', path);
  }
}
