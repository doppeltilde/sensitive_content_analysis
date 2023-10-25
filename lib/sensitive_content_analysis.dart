import 'package:flutter/services.dart';

const methodChannel = MethodChannel('sensitive_content_analysis');

class SensitiveContentAnalysis {
  /// Analyzes an image for sensitive content.
  ///
  /// Returns a `bool` indicating whether the image is sensitive.
  Future<bool?> analyzeImage(Uint8List file) async {
    try {
      final dynamic isSensitive =
          await methodChannel.invokeMethod('analyzeImage', file);
      return isSensitive;
    } on PlatformException catch (e) {
      throw UnimplementedError(e.message);
    }
  }

  /// Analyzes an network image for sensitive content.
  ///
  /// Returns a `bool` indicating whether the image is sensitive.
  Future<bool?> analyzeNetworkImage({required String url}) async {
    try {
      final dynamic isSensitive =
          await methodChannel.invokeMethod('analyzeNetworkImage', {"url": url});
      return isSensitive;
    } on PlatformException catch (e) {
      throw UnimplementedError(e.message);
    }
  }

  /// Check Policy.
  ///
  /// Returns a `int` indicating the policy value.
  Future<int?> checkPolicy() async {
    try {
      final result = await methodChannel.invokeMethod('checkPolicy');
      return result;
    } on PlatformException catch (e) {
      throw UnimplementedError(e.message);
    }
  }
}
