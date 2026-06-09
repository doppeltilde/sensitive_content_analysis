import 'dart:async';
import 'package:sensitive_content_analysis/sensitive_content_analysis.dart';
import 'package:sensitive_content_analysis_example/main.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CameraSensitiveAnalysisScreen extends StatefulWidget {
  final String participantUUID;

  const CameraSensitiveAnalysisScreen({
    super.key,
    required this.participantUUID,
  });

  @override
  State<CameraSensitiveAnalysisScreen> createState() =>
      _CameraSensitiveAnalysisScreenState();
}

class _CameraSensitiveAnalysisScreenState
    extends State<CameraSensitiveAnalysisScreen> {
  CameraController? _cameraController;
  VideoStreamAnalyzer? _analyzer;
  StreamSubscription<SensitivityAnalysisResult>? _analysisSubscription;

  bool _isInitializing = true;
  bool _isAnalyzingFrame = false;
  bool _isStreamInterrupted = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeSystem();
  }

  Future<void> _initializeSystem() async {
    final policy = await SensitiveContentAnalysis().checkPolicy();
    print("Analysis Policy: $policy");

    if (policy == AnalysisPolicy.disabled) {
      print(
          "⚠️ Sensitive content analysis is DISABLED. Check entitlement + device settings.");
    }
    try {
      _analyzer = await sca.createVideoStreamAnalyzer(
        participantUUID: widget.participantUUID,
        streamDirection: StreamDirection.outgoing,
      );

      _subscribeToAnalysisChanges();

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception("No physical cameras detected on this device.");
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      await Future.delayed(const Duration(milliseconds: 100));
      await _analyzer!.continueStream();

      _startFrameStreamingPipeline();

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _subscribeToAnalysisChanges() {
    if (_analyzer == null) return;

    _analysisSubscription = _analyzer!.analysisChanges.listen(
      (SensitivityAnalysisResult result) async {
        print("🔍 Full Analysis Result: $result");
        setState(() {
          _isStreamInterrupted = result.shouldInterruptVideo;
        });
      },
      onError: (error) {
        debugPrint('Error caught from analysis EventChannel: $error');
      },
    );
  }

  DateTime? _lastAnalysisTime;
  final int _throttleMs = 400;

  void _startFrameStreamingPipeline() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _cameraController!.startImageStream((CameraImage image) async {
      if (_analyzer == null || _isAnalyzingFrame) return;

      final now = DateTime.now();
      if (_lastAnalysisTime != null &&
          now.difference(_lastAnalysisTime!).inMilliseconds < _throttleMs) {
        return;
      }
      _lastAnalysisTime = now;

      _isAnalyzingFrame = true;

      try {
        final plane = image.planes[0];
        final Uint8List bytes = plane.bytes;
        final int bytesPerRow = plane.bytesPerRow;

        print(
            "📤 Sending frame: ${image.width}x   ${image.height}, bytes: ${plane.bytes.length}");

        await _analyzer!.analyzeFrame(
          bytes: bytes,
          width: image.width,
          height: image.height,
          bytesPerRow: bytesPerRow,
        );
      } catch (e) {
        debugPrint("Failed to parse or analyze frame: $e");
      } finally {
        _isAnalyzingFrame = false;
      }
    });
  }

  @override
  void dispose() {
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }
    _cameraController?.dispose();

    _analysisSubscription?.cancel();

    _analyzer?.endAnalysis();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Sensitive Content Stream")),
      body: Stack(
        children: [
          if (_cameraController != null &&
              _cameraController!.value.isInitialized)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(child: Text("Camera view unavailable.")),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Card(
                elevation: 8,
                color: _isStreamInterrupted
                    ? Colors.red.withValues(alpha: 0.9)
                    : Colors.green.withValues(alpha: 0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 20.0),
                  child: Row(
                    children: [
                      Icon(
                        _isStreamInterrupted
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isStreamInterrupted ? "NOT SAFE" : "SAFE",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isStreamInterrupted
                                  ? "Sensitive content detected in frame."
                                  : "No sensitive content detected.",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
