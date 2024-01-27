import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensitive_content_analysis/sensitive_content_analysis.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final sca = SensitiveContentAnalysis();

  @override
  void initState() {
    super.initState();
  }

  Future<void> analyzeImage() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Pick an image.
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        Uint8List imageData = await image.readAsBytes();

        // Analyze the image for sensitive content.
        bool? isSensitive = await sca.analyzeImage(imageData);
        debugPrint("SENSITIVE: $isSensitive");
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> analyzeNetworkImage(String? url) async {
    try {
      if (url != null) {
        // Analyze the image for sensitive content.
        bool? isSensitive = await sca.analyzeNetworkImage(url: url);
        debugPrint("SENSITIVE: $isSensitive");
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> analyzeDownloadedVideo() async {
    try {
      Dio dio = Dio();
      Directory tempDir = await getTemporaryDirectory();

      const url = "https://developer.apple.com/sample-code/web/qr-sca.mov";
      final videoName = p.basename(url);
      final file = File("${tempDir.path}/$videoName");
      final response = await dio.download(url, file.path);

      if (response.statusCode == 200) {
        bool? isSensitive = await sca.analyzeVideo(url: file.path);
        debugPrint("SENSITIVE: $isSensitive");
        await file.delete();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> analyzeSelectedVideo() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'video',
        extensions: <String>['mp4', 'mkv', 'avi', 'mov'],
      );
      final XFile? selectedFile =
          await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

      if (selectedFile != null) {
        final bytes = await selectedFile.readAsBytes();
        final videoName = p.basename(selectedFile.path);

        Directory tempDir = await getTemporaryDirectory();
        File tempFile = File('${tempDir.path}/$videoName');

        await tempFile.writeAsBytes(bytes);

        bool? isSensitive = await sca.analyzeVideo(url: tempFile.path);
        debugPrint("SENSITIVE: $isSensitive");
        await tempFile.delete();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  checkPolicy() async {
    int? policy = await sca.checkPolicy();
    debugPrint("Policy: $policy");
  }

  final String? analyzeUrl =
      "https://docs-assets.developer.apple.com/published/517e263450/rendered2x-1685188934.png";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton(
              onPressed: () async => await analyzeImage(),
              child: const Text("Select Image."),
            ),
            ElevatedButton(
              onPressed: () async => await analyzeNetworkImage(analyzeUrl),
              child: const Text("Select Network Image."),
            ),
            ElevatedButton(
              onPressed: () async => await analyzeDownloadedVideo(),
              child: const Text("Analyze Downloaded Video."),
            ),
            ElevatedButton(
              onPressed: () async => await analyzeSelectedVideo(),
              child: const Text("Analyze Selected Video."),
            ),
            ElevatedButton(
              onPressed: () => checkPolicy(),
              child: const Text("Check Policy."),
            ),
          ]),
        ),
      ),
    );
  }
}
