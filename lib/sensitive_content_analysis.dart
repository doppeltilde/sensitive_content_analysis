import 'package:flutter/services.dart';

const methodChannel = MethodChannel('sensitive_content_analysis');

class SensitiveContentAnalysis {
  /// Analyzes an image for sensitive content.
  ///
  /// Returns a [SensitivityAnalysisResult] with sensitivity status and detected content types.
  Future<SensitivityAnalysisResult?> analyzeImage(Uint8List file) async {
    try {
      final Map<Object?, Object?>? result =
          await methodChannel.invokeMapMethod('analyzeImage', file);
      if (result == null) return null;
      return SensitivityAnalysisResult.fromMap(result);
    } on PlatformException catch (e) {
      throw UnimplementedError(e.message);
    }
  }

  /// Analyzes an network image for sensitive content.
  ///
  /// Returns a [SensitivityAnalysisResult] with sensitivity status and detected content types.
  Future<SensitivityAnalysisResult?> analyzeNetworkImage(
      {required String url}) async {
    try {
      final Map<Object?, Object?>? result = await methodChannel
          .invokeMapMethod('analyzeNetworkImage', {"url": url});
      if (result == null) return null;
      return SensitivityAnalysisResult.fromMap(result);
    } on PlatformException catch (e) {
      throw UnimplementedError(e.message);
    }
  }

  /// Analyzes an video for sensitive content.
  ///
  /// Returns a [SensitivityAnalysisResult] with sensitivity status and detected content types.
  Future<SensitivityAnalysisResult?> analyzeVideo({required String url}) async {
    try {
      final Map<Object?, Object?>? result = await methodChannel
          .invokeMapMethod('analyzeVideo', {"url": Uri.file(url).toString()});
      if (result == null) return null;
      return SensitivityAnalysisResult.fromMap(result);
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

class SensitivityAnalysisResult {
  final bool isSensitive;
  final List<String> detectedTypes;

  const SensitivityAnalysisResult({
    required this.isSensitive,
    required this.detectedTypes,
  });

  factory SensitivityAnalysisResult.fromMap(Map<Object?, Object?> map) {
    return SensitivityAnalysisResult(
      isSensitive: map['isSensitive'] as bool? ?? false,
      detectedTypes: (map['detectedTypes'] as List<Object?>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}
