import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensitive_content_analysis/sensitive_content_analysis.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> analyzeImage() async {
    try {
      final sca = SensitiveContentAnalysis.instance;
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
      final sca = SensitiveContentAnalysis.instance;

      if (url != null) {
        // Analyze the image for sensitive content.
        bool? isSensitive = await sca.analyzeNetworkImage(url: url);
        debugPrint("SENSITIVE: $isSensitive");
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  final String analyzeUrl =
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
              onPressed: () => analyzeImage(),
              child: const Text("Select Image."),
            ),
            ElevatedButton(
              onPressed: () => analyzeNetworkImage(analyzeUrl),
              child: const Text("Select Network Image."),
            ),
          ]),
        ),
      ),
    );
  }
}
