import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensitive_content_analysis/sensitive_content_analysis.dart';
import 'package:path/path.dart' as p;
import 'package:sensitive_content_analysis_example/home_feed.dart';
import 'package:sensitive_content_analysis_example/video_analyzer.dart';

late final SensitiveContentAnalysis sca;

void main() {
  sca = SensitiveContentAnalysis();
  runApp(MaterialApp(theme: ThemeData.dark(), home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<void> analyzeImage() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Pick an image.
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        Uint8List imageData = await image.readAsBytes();

        // Analyze the image for sensitive content.
        SensitivityAnalysisResult? isSensitive =
            await sca.analyzeImage(imageData);
        _showResultDialog(
            "Analysis Result", "SENSITIVE: ${isSensitive?.isSensitive}");
      }
    } catch (e) {
      _showResultDialog("Error", e.toString());
    }
  }

  Future<void> analyzeNetworkImage() async {
    try {
      const url =
          "https://docs-assets.developer.apple.com/published/517e263450/rendered2x-1685188934.png";

      // Analyze the image for sensitive content.
      SensitivityAnalysisResult? isSensitive =
          await sca.analyzeNetworkImage(url: url);
      _showResultDialog(
          "Analysis Result", "SENSITIVE: ${isSensitive?.isSensitive}");
    } catch (e) {
      _showResultDialog("Error", e.toString());
    }
  }

  Future<void> analyzeNetworkVideo() async {
    try {
      Dio dio = Dio();
      Directory tempDir = await getTemporaryDirectory();

      const url = "https://developer.apple.com/sample-code/web/qr-sca.mov";
      final videoName = p.basename(url);
      final file = File("${tempDir.path}/$videoName");
      final response = await dio.download(url, file.path);

      if (response.statusCode == 200) {
        SensitivityAnalysisResult? isSensitive =
            await sca.analyzeVideo(url: file.path);
        _showResultDialog(
            "Analysis Result", "SENSITIVE: ${isSensitive?.isSensitive}");
        await file.delete();
      }
    } catch (e) {
      _showResultDialog("Error", e.toString());
    }
  }

  Future<void> analyzeLocalVideo() async {
    try {
      FilePickerResult? selectedFile = await FilePicker.pickFiles(
        allowMultiple: false,
        type: FileType.video,
      );
      if (selectedFile != null) {
        SensitivityAnalysisResult? isSensitive =
            await sca.analyzeVideo(url: selectedFile.files.first.path!);
        _showResultDialog(
            "Analysis Result", "SENSITIVE: ${isSensitive?.isSensitive}");
      }
    } catch (e) {
      _showResultDialog("Error", e.toString());
    }
  }

  Future<void> checkPolicy() async {
    try {
      AnalysisPolicy? policy = await sca.checkPolicy();
      _showResultDialog("Policy Check", "Policy: ${policy?.name}");
    } catch (e) {
      _showResultDialog("Error", e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Plugin example app'),
      ),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(
            onPressed: () async => await analyzeImage(),
            child: const Text("Select Image."),
          ),
          TextButton(
            onPressed: () async => await analyzeNetworkImage(),
            child: const Text("Select Network Image."),
          ),
          TextButton(
            onPressed: () async => await analyzeNetworkVideo(),
            child: const Text("Analyze Downloaded Video."),
          ),
          TextButton(
            onPressed: () async => await analyzeLocalVideo(),
            child: const Text("Analyze Selected Video."),
          ),
          TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CameraSensitiveAnalysisScreen(
                      participantUUID: "participantUUIDExample"),
                )),
            child: const Text("Analyze Camera Stream."),
          ),
          TextButton(
            onPressed: () async => await checkPolicy(),
            child: const Text("Check Policy."),
          ),
          warningWidget(),
        ]),
      ),
    );
  }

  void _showResultDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  TextButton warningWidget() {
    return TextButton(
      onPressed: () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.0),
              ),
              elevation: 10,
              backgroundColor: Theme.of(context).cardColor,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 18+ Icon Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: .1),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        "18+",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      "Age Verification Required",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      "The home feed contains content intended for mature audiences. Please verify that you are 18 years or older to proceed.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FeedScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "I am 18 or older",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Go Back",
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: const Text("Home feed example."),
    );
  }
}
