import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sensitive_content_analysis/sensitive_content_analysis_service.dart';

abstract class SensitiveContentAnalysis extends PlatformInterface {
  /// Constructs a GamesServicesPlatform.
  SensitiveContentAnalysis() : super(token: _token);

  static final Object _token = Object();

  static SensitiveContentAnalysis _instance = SensitiveContentAnalysisService();

  /// The default instance of [GamesServicesPlatform] to use.
  ///
  /// Defaults to [MethodChannelGamesServices].
  static SensitiveContentAnalysis get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [GamesServicesPlatform] when they register themselves.
  static set instance(SensitiveContentAnalysis instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Analyzes an image for sensitive content.
  ///
  /// Returns a `bool` indicating whether the image is sensitive.
  Future<bool?> analyzeImage(Uint8List file) async {
    throw UnimplementedError("not implemented.");
  }

  /// Analyzes an network image for sensitive content.
  ///
  /// Returns a `bool` indicating whether the image is sensitive.
  Future<bool?> analyzeNetworkImage({required String url}) async {
    throw UnimplementedError("not implemented.");
  }

  /// Check Policy.
  ///
  /// Returns a `bool` indicating whether the image is sensitive.
  Future<bool?> checkPolicy() async {
    throw UnimplementedError("not implemented.");
  }
}
