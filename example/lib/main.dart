import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensitive_content_analysis/sensitive_content_analysis.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(MaterialApp(theme: ThemeData.dark(), home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final sca = SensitiveContentAnalysis();

  Future<void> analyzeImage() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Pick an image.
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        Uint8List imageData = await image.readAsBytes();

        // Analyze the image for sensitive content.
        bool? isSensitive = await sca.analyzeImage(imageData);
        _showResultDialog("Analysis Result", "SENSITIVE: $isSensitive");
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
      bool? isSensitive = await sca.analyzeNetworkImage(url: url);
      _showResultDialog("Analysis Result", "SENSITIVE: $isSensitive");
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
        bool? isSensitive = await sca.analyzeVideo(url: file.path);
        _showResultDialog("Analysis Result", "SENSITIVE: $isSensitive");
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
        bool? isSensitive =
            await sca.analyzeVideo(url: selectedFile.files.first.path!);
        _showResultDialog("Analysis Result", "SENSITIVE: $isSensitive");
      }
    } catch (e) {
      _showResultDialog("Error", e.toString());
    }
  }

  Future<void> checkPolicy() async {
    try {
      int? policy = await sca.checkPolicy();
      _showResultDialog("Policy Check", "Policy: $policy");
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
            onPressed: () async => await checkPolicy(),
            child: const Text("Check Policy."),
          ),
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
}
