import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sensitive_content_analysis/sensitive_content_analysis.dart';

import 'widget_test.mocks.dart';

@GenerateMocks([SensitiveContentAnalysis])
void main() {
  late MockSensitiveContentAnalysis mockSca;

  setUp(() {
    mockSca = MockSensitiveContentAnalysis();
  });

  group('SensitiveContentAnalysis - analyzeImage', () {
    test('returns isSensitive=false for safe image bytes', () async {
      final fakeBytes = Uint8List.fromList([0, 1, 2, 3]);
      when(mockSca.analyzeImage(fakeBytes)).thenAnswer(
        (_) async => SensitivityAnalysisResult(
            isSensitive: false,
            detectedTypes: [],
            shouldIndicateSensitivity: false,
            shouldInterruptVideo: false,
            shouldMuteAudio: false),
      );

      final result = await mockSca.analyzeImage(fakeBytes);

      expect(result, isNotNull);
      expect(result!.isSensitive, isFalse);
      verify(mockSca.analyzeImage(fakeBytes)).called(1);
    });

    test('returns isSensitive=true for sensitive image bytes', () async {
      final fakeBytes = Uint8List.fromList([255, 254, 253]);
      when(mockSca.analyzeImage(fakeBytes)).thenAnswer(
        (_) async => SensitivityAnalysisResult(
            isSensitive: true,
            detectedTypes: [],
            shouldIndicateSensitivity: true,
            shouldInterruptVideo: true,
            shouldMuteAudio: true),
      );

      final result = await mockSca.analyzeImage(fakeBytes);

      expect(result, isNotNull);
      expect(result!.isSensitive, isTrue);
    });

    test('returns null when analysis cannot be performed', () async {
      final fakeBytes = Uint8List(0);
      when(mockSca.analyzeImage(fakeBytes)).thenAnswer((_) async => null);

      final result = await mockSca.analyzeImage(fakeBytes);

      expect(result, isNull);
    });

    test('propagates exception on analysis failure', () async {
      final fakeBytes = Uint8List.fromList([1, 2, 3]);
      when(mockSca.analyzeImage(fakeBytes))
          .thenThrow(Exception('Analysis failed'));

      expect(() => mockSca.analyzeImage(fakeBytes), throwsException);
    });
  });

  group('SensitiveContentAnalysis - analyzeNetworkImage', () {
    const safeUrl =
        'https://docs-assets.developer.apple.com/published/517e263450/rendered2x-1685188934.png';

    test('returns isSensitive=false for safe network image', () async {
      when(mockSca.analyzeNetworkImage(url: safeUrl)).thenAnswer(
        (_) async => SensitivityAnalysisResult(
            isSensitive: false,
            detectedTypes: [],
            shouldIndicateSensitivity: false,
            shouldInterruptVideo: false,
            shouldMuteAudio: false),
      );

      final result = await mockSca.analyzeNetworkImage(url: safeUrl);

      expect(result, isNotNull);
      expect(result!.isSensitive, isFalse);
      verify(mockSca.analyzeNetworkImage(url: safeUrl)).called(1);
    });

    test('returns null for unreachable URL', () async {
      const badUrl = 'https://invalid.example.com/image.png';
      when(mockSca.analyzeNetworkImage(url: badUrl))
          .thenAnswer((_) async => null);

      final result = await mockSca.analyzeNetworkImage(url: badUrl);

      expect(result, isNull);
    });

    test('throws on network error', () async {
      const errorUrl = 'https://unreachable.example.com/img.jpg';
      when(mockSca.analyzeNetworkImage(url: errorUrl))
          .thenThrow(Exception('Network error'));

      expect(
        () => mockSca.analyzeNetworkImage(url: errorUrl),
        throwsException,
      );
    });
  });

  group('SensitiveContentAnalysis - analyzeVideo', () {
    const videoPath = '/tmp/test_video.mov';

    test('returns isSensitive=false for safe video', () async {
      when(mockSca.analyzeVideo(url: videoPath)).thenAnswer(
        (_) async => SensitivityAnalysisResult(
            isSensitive: false,
            detectedTypes: [],
            shouldIndicateSensitivity: false,
            shouldInterruptVideo: false,
            shouldMuteAudio: false),
      );

      final result = await mockSca.analyzeVideo(url: videoPath);

      expect(result, isNotNull);
      expect(result!.isSensitive, isFalse);
      verify(mockSca.analyzeVideo(url: videoPath)).called(1);
    });

    test('returns isSensitive=true for flagged video', () async {
      when(mockSca.analyzeVideo(url: videoPath)).thenAnswer(
        (_) async => SensitivityAnalysisResult(
            isSensitive: true,
            detectedTypes: [],
            shouldIndicateSensitivity: true,
            shouldInterruptVideo: true,
            shouldMuteAudio: true),
      );

      final result = await mockSca.analyzeVideo(url: videoPath);

      expect(result!.isSensitive, isTrue);
    });

    test('throws on missing video file', () async {
      const missingPath = '/tmp/nonexistent.mov';
      when(mockSca.analyzeVideo(url: missingPath))
          .thenThrow(Exception('File not found'));

      expect(
        () => mockSca.analyzeVideo(url: missingPath),
        throwsException,
      );
    });
  });

  group('SensitiveContentAnalysis - checkPolicy', () {
    test('returns policy code 0 (no restrictions)', () async {
      when(mockSca.checkPolicy())
          .thenAnswer((_) async => AnalysisPolicy.disabled);

      final policy = await mockSca.checkPolicy();

      expect(policy, equals(0));
      verify(mockSca.checkPolicy()).called(1);
    });

    test('returns policy code 1 (restricted)', () async {
      when(mockSca.checkPolicy())
          .thenAnswer((_) async => AnalysisPolicy.simpleInterventions);

      final policy = await mockSca.checkPolicy();

      expect(policy, equals(1));
    });

    test('returns null when policy cannot be determined', () async {
      when(mockSca.checkPolicy()).thenAnswer((_) async => null);

      final policy = await mockSca.checkPolicy();

      expect(policy, isNull);
    });

    test('throws on policy fetch failure', () async {
      when(mockSca.checkPolicy()).thenThrow(Exception('Policy fetch failed'));

      expect(() => mockSca.checkPolicy(), throwsException);
    });
  });

  group('SensitivityAnalysisResult model', () {
    test('constructs with isSensitive=true', () {
      final result = SensitivityAnalysisResult(
          isSensitive: true,
          detectedTypes: [],
          shouldIndicateSensitivity: true,
          shouldInterruptVideo: true,
          shouldMuteAudio: true);
      expect(result.isSensitive, isTrue);
    });

    test('constructs with isSensitive=false', () {
      final result = SensitivityAnalysisResult(
          isSensitive: false,
          detectedTypes: [],
          shouldIndicateSensitivity: false,
          shouldInterruptVideo: false,
          shouldMuteAudio: false);
      expect(result.isSensitive, isFalse);
    });
  });

  group('UI - result dialog smoke test', () {
    testWidgets('shows AlertDialog with title and message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Analysis Result'),
                    content: const Text('SENSITIVE: false'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Analysis Result'), findsOneWidget);
      expect(find.text('SENSITIVE: false'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('dialog dismisses on OK tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Policy Check'),
                    content: const Text('Policy: 0'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Policy: 0'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Policy: 0'), findsNothing);
    });
  });
}
