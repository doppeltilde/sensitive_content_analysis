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
  bool _isContinuing = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeSystem();
  }

  Future<void> _initializeSystem() async {
    final policy = await sca.checkPolicy();
    debugPrint("Analysis Policy: $policy");

    if (policy == .disabled) {
      debugPrint(
        "⚠️ Sensitive content analysis is DISABLED. Check entitlement + device settings.",
      );
    }
    try {
      _analyzer = await sca.createVideoStreamAnalyzer(
        participantUUID: widget.participantUUID,
        streamDirection: .incoming,
      );

      _subscribeToAnalysisChanges();

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception("No physical cameras detected on this device.");
      }

      _cameraController = CameraController(
        cameras.first,
        .medium,
        enableAudio: true,
        imageFormatGroup: .bgra8888,
      );

      await _cameraController!.initialize();

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
        debugPrint("🔍 Full Analysis Result: $result");

        if (result.shouldInterruptVideo && !_isContinuing) {
          if (_cameraController != null &&
              _cameraController!.value.isStreamingImages) {
            await _cameraController!.stopImageStream();
          }
          setState(() {
            _isStreamInterrupted = true;
          });
        }
      },
      onError: (error) {
        debugPrint('Error caught from analysis EventChannel: $error');
      },
    );
  }

  Future<void> _onContinueTapped() async {
    if (_analyzer == null || _isContinuing) return;

    setState(() {
      _isContinuing = true;
    });

    try {
      await _analyzer!.continueStream();

      setState(() {
        _isStreamInterrupted = false;
        _isContinuing = false;
      });

      await Future.delayed(const Duration(milliseconds: 200));

      _startFrameStreamingPipeline();
    } catch (e) {
      debugPrint("Failed to continue stream: $e");
      setState(() => _isContinuing = false);
    }
  }

  DateTime? _lastAnalysisTime;
  final int _throttleMs = 200;

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const .all(24.0),
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: .center,
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
              child: _isStreamInterrupted
                  ? SizedBox.shrink()
                  : CameraPreview(_cameraController!),
            )
          else
            const Center(child: Text("Camera view unavailable.")),
          if (!_isStreamInterrupted)
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
                  shape: RoundedRectangleBorder(borderRadius: .circular(12)),
                  child: Padding(
                    padding: const .symmetric(vertical: 16.0, horizontal: 20.0),
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
                            crossAxisAlignment: .start,
                            mainAxisSize: .min,
                            children: [
                              Text(
                                _isStreamInterrupted ? "NOT SAFE" : "SAFE",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: .bold,
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
          if (_isStreamInterrupted)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _isStreamInterrupted ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: .blur(sigmaX: 50, sigmaY: 50),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: Column(
                        mainAxisAlignment: .center,
                        children: [
                          const Icon(
                            Icons.visibility_off_rounded,
                            color: Colors.white,
                            size: 56,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Sensitive Content Detected",
                            textAlign: .center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: .bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "The Video is paused because the video\nmay be showing something sensitive.",
                            textAlign: .center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: _isContinuing ? null : _onContinueTapped,
                            icon: _isContinuing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.play_arrow_rounded),
                            label: Text(
                              _isContinuing ? "Resuming…" : "Resume Video",
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              padding: const .symmetric(
                                horizontal: 28,
                                vertical: 14,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: .w600,
                              ),
                            ),
                          ),
                        ],
                      ),
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
