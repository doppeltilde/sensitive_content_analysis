import 'package:flutter/services.dart';

const _methodChannel = MethodChannel('sensitive_content_analysis');

class SensitiveContentAnalysis {
  /// Analyzes a local image for sensitive content.
  Future<SensitivityAnalysisResult?> analyzeImage(Uint8List file) async {
    try {
      final Map<Object?, Object?>? result = await _methodChannel
          .invokeMapMethod('analyzeImage', file);
      if (result == null) return null;
      return .fromMap(result);
    } on PlatformException catch (e) {
      throw UnimplementedError(e.message);
    }
  }

  /// Analyzes a network image for sensitive content.
  Future<SensitivityAnalysisResult?> analyzeNetworkImage({
    required String url,
  }) async {
    try {
      final Map<Object?, Object?>? result = await _methodChannel
          .invokeMapMethod('analyzeNetworkImage', {'url': url});
      if (result == null) return null;
      return .fromMap(result);
    } on PlatformException catch (e) {
      throw UnimplementedError(e.message);
    }
  }

  /// Analyzes a local video file for sensitive content.
  Future<SensitivityAnalysisResult?> analyzeVideo({required String url}) async {
    try {
      final Map<Object?, Object?>? result = await _methodChannel
          .invokeMapMethod('analyzeVideo', {'url': url});
      if (result == null) return null;
      return .fromMap(result);
    } on PlatformException catch (e) {
      throw UnimplementedError(e.message);
    }
  }

  /// Returns the current [AnalysisPolicy].
  Future<AnalysisPolicy?> checkPolicy() async {
    try {
      final int? raw = await _methodChannel.invokeMethod('checkPolicy');
      if (raw == null) return null;
      return .fromInt(raw);
    } on PlatformException catch (e) {
      throw UnimplementedError(e.message);
    }
  }

  /// Creates a [VideoStreamAnalyzer] for the given participant.
  ///
  /// Throws a [PlatformException] if Communication Safety or Sensitive
  /// Content Warnings is not enabled on the device (iOS 26+ / macOS 26+).
  Future<VideoStreamAnalyzer> createVideoStreamAnalyzer({
    required String participantUUID,
    required StreamDirection streamDirection,
  }) async {
    final eventChannelName =
        'sensitive_content_analysis/stream/$participantUUID';

    try {
      await _methodChannel.invokeMethod('createVideoStreamAnalyzer', {
        'participantUUID': participantUUID,
        'streamDirection': streamDirection.index,
        'eventChannelName': eventChannelName,
      });
    } on PlatformException catch (e) {
      throw UnimplementedError(e.message);
    }

    return ._(
      participantUUID: participantUUID,
      eventChannel: EventChannel(eventChannelName),
    );
  }
}

// ---------------------------------------------------------------------------
// VideoStreamAnalyzer
// ---------------------------------------------------------------------------

/// Monitors a live video stream for sensitive content.
///
/// Obtain an instance via [SensitiveContentAnalysis.createVideoStreamAnalyzer].
/// Listen to [analysisChanges] to react to detections, call [continueStream]
/// after handling an interruption, and call [endAnalysis] when the stream ends.
///
/// Available on iOS 26+ / macOS 26+ only. On older OS versions
/// [SensitiveContentAnalysis.createVideoStreamAnalyzer] will throw.
class VideoStreamAnalyzer {
  VideoStreamAnalyzer._({
    required this.participantUUID,
    required this._eventChannel,
  });

  final String participantUUID;
  final EventChannel _eventChannel;

  /// A stream of [SensitivityAnalysisResult] pushed whenever the framework
  /// detects a change in the video stream's sensitivity status.
  ///
  /// The stream closes when [endAnalysis] is called or the native side ends.
  Stream<SensitivityAnalysisResult> get analysisChanges {
    return _eventChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map((event) => .fromMap(event as Map<Object?, Object?>));
  }

  /// Passes a raw video frame to the analyzer.
  ///
  /// Use this when your app decodes its own video stream. [bytes] must be
  /// BGRA-formatted pixel data matching [width] × [height].
  ///
  /// For AVCaptureDeviceInput or VTDecompressionSession, call
  /// beginAnalysis on the native side directly instead.
  Future<void> analyzeFrame({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
  }) async {
    try {
      await _methodChannel.invokeMethod('analyzeVideoStreamFrame', {
        'participantUUID': participantUUID,
        'bytes': bytes,
        'width': width,
        'height': height,
        'bytesPerRow': bytesPerRow,
      });
    } on PlatformException catch (e) {
      throw UnimplementedError(e.message);
    }
  }

  /// Signals that the app is ready to resume after handling a
  /// [SensitivityAnalysisResult.shouldInterruptVideo] event.
  Future<void> continueStream() async {
    try {
      await _methodChannel.invokeMethod('continueVideoStream', {
        'participantUUID': participantUUID,
      });
    } on PlatformException catch (e) {
      throw UnimplementedError(e.message);
    }
  }

  /// Stops analysis and releases the native analyzer for this participant.
  ///
  /// After calling this, [analysisChanges] will close and this instance
  /// should be discarded.
  Future<void> endAnalysis() async {
    try {
      await _methodChannel.invokeMethod('endVideoStreamAnalysis', {
        'participantUUID': participantUUID,
      });
    } on PlatformException catch (e) {
      throw UnimplementedError(e.message);
    }
  }
}

// ---------------------------------------------------------------------------
// SensitivityAnalysisResult
// ---------------------------------------------------------------------------

class SensitivityAnalysisResult {
  const SensitivityAnalysisResult({
    required this.isSensitive,
    required this.detectedTypes,
    required this.shouldIndicateSensitivity,
    required this.shouldInterruptVideo,
    required this.shouldMuteAudio,
  });

  /// Whether the content is considered sensitive.
  final bool isSensitive;

  /// Which types of sensitive content were detected (iOS 26+ / macOS 26+).
  final List<DetectedContentType> detectedTypes;

  /// App should indicate the presence of sensitive content to the user.
  /// Available on iOS/ipadOS 26+ always false on older OS versions.
  final bool shouldIndicateSensitivity;

  /// App should interrupt video playback.
  /// Available on iOS/ipadOS 26+ always false on older OS versions.
  final bool shouldInterruptVideo;

  /// App should mute the audio of the current video stream.
  /// Available on iOS/ipadOS 26+ always false on older OS versions.
  final bool shouldMuteAudio;

  factory SensitivityAnalysisResult.fromMap(Map<Object?, Object?> map) {
    bool toBool(String key) => map[key] as bool? ?? false;

    return SensitivityAnalysisResult(
      isSensitive: toBool('isSensitive'),
      shouldIndicateSensitivity: toBool('shouldIndicateSensitivity'),
      shouldInterruptVideo: toBool('shouldInterruptVideo'),
      shouldMuteAudio: toBool('shouldMuteAudio'),
      detectedTypes: (map['detectedTypes'] as List? ?? [])
          .whereType<String>()
          .map(DetectedContentType.fromString)
          .whereType<DetectedContentType>()
          .toList(),
    );
  }

  @override
  String toString() =>
      'SensitivityAnalysisResult('
      'isSensitive: $isSensitive, '
      'detectedTypes: $detectedTypes, '
      'shouldIndicateSensitivity: $shouldIndicateSensitivity, '
      'shouldInterruptVideo: $shouldInterruptVideo, '
      'shouldMuteAudio: $shouldMuteAudio)';
}

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum DetectedContentType {
  sexuallyExplicit,
  goreOrViolence;

  static DetectedContentType? fromString(String value) => switch (value) {
    'sexuallyExplicit' => .sexuallyExplicit,
    'goreOrViolence' => .goreOrViolence,
    _ => null,
  };
}

enum AnalysisPolicy {
  /// Analysis is disabled; always returns null from analysis methods.
  disabled,

  /// Simple interventions (e.g. blurring) are suggested.
  simpleInterventions,

  /// Descriptive interventions with richer guidance are suggested.
  descriptiveInterventions;

  static AnalysisPolicy fromInt(int value) => switch (value) {
    0 => .disabled,
    1 => .simpleInterventions,
    2 => .descriptiveInterventions,
    _ => throw ArgumentError('Unknown AnalysisPolicy value: $value'),
  };
}

enum StreamDirection {
  /// The local device's outgoing camera stream.
  outgoing,

  /// An incoming stream from a remote participant.
  incoming,
}
