import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SensitiveContentAnalysis {
  static const methodChannel = MethodChannel('sensitive_content_analysis');

  /// Analyzes an image for sensitive content.
  ///
  /// Returns a `bool` indicating whether the image is sensitive.
  static Future<bool> analyzeImage(Uint8List file) async {
    try {
      final bool isSensitive =
          await methodChannel.invokeMethod('analyzeImage', file);
      return isSensitive;
    } on PlatformException catch (e) {
      debugPrint(e.toString());
      return false;
    }
  }

  /// Intervenes on an image that has been identified as sensitive.
  ///
  /// The specific intervention behavior will vary depending on the platform.
  static Future<void> intervene(String path) async {
    await methodChannel.invokeMethod('intervene', path);
  }
}
