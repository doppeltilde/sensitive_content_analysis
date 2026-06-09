# Sensitive Content Analysis

#### Provide a safer experience in your app by detecting and alerting users to nudity in images and videos before displaying them onscreen.

<img src="https://docs-assets.developer.apple.com/published/36d145c8a9/renderedDark2x-1684208404.png" width="500px"/>
<img src="https://docs-assets.developer.apple.com/published/b266a0fa980fd3b5cc0b3e200e137495/sensitivecontentanalysis-2~dark%402x.png" width="500px" />
<img src="https://www.apple.com/v/child-safety/overview/a/images/overview/communication/safety__c8aw8hnf4nwy_large_2x.jpg" width="250px" />

[![Pub](https://img.shields.io/pub/v/sensitive_content_analysis.svg?style=popout&include_prereleases)](https://pub.dev/packages/sensitive_content_analysis)

Flutter package for interacting with Apple's
[SensitiveContentAnalysis Framework](https://developer.apple.com/documentation/sensitivecontentanalysis).

#### Minimum requirements

Lower deployment versions may be targeted, however, it's important to note that the SCA Framework is exclusively compatible with:
- iOS/iPadOS `>=17.0`
- macOS `>=14.0`

#### Other Notice's

- In order to maintain the package's lightweight nature and grant you complete control over your UI's appearance, this package intentionally refrains from incorporating an overlay or blur feature.
- The framework only works on physical devices. [#3](https://github.com/doppeltilde/sensitive_content_analysis/issues/3)

---

### Install

#### Add the app entitlement:

The OS requires the `com.apple.developer.sensitivecontentanalysis.client`
entitlement in your app’s code signature to use SensitiveContentAnalysis. Calls
to the framework fail to return positive results without it. You can can add
this entitlement to your app by enabling the Sensitive Content Analysis
capability in Xcode.

```xml
<key>com.apple.developer.sensitivecontentanalysis.client</key>
<array>
	<string>analysis</string>
</array>
```

#### Install the test profile

For testing purposes, Apple offers a test profile that enables you to evaluate the frameworks functionality without the necessity of installing actual NSFW content.

<img src="https://docs-assets.developer.apple.com/published/517e263450/rendered2x-1685188934.png" width="120px" />

See:
https://developer.apple.com/documentation/sensitivecontentanalysis/testing-your-app-s-response-to-sensitive-media

---

## Usage and Examples

### Check Policy:

```dart
    try {
      AnalysisPolicy? policy = await sca.checkPolicy();
      _showResultDialog("Policy Check", "Policy: ${policy?.name}");
      /// Analysis is disabled; always returns null from analysis methods.
      /// .disabled

      /// Simple interventions (e.g. blurring) are suggested.
      /// .simpleInterventions

      /// Descriptive interventions with richer guidance are suggested.
      /// .descriptiveInterventions

    } catch (e) {
      _showResultDialog("Error", e.toString());
    }
```

### Analyze Image

#### File Image:

```dart
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
```

#### Network Image:

```dart
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
```

### Analyze Video

#### Network Video:

```dart
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
```

#### Local Video:

```dart
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
```

#### Video Stream:
> [!NOTE]  
> Please refer to the [`video_stream_analyzer`](example/lib/video_stream_analyzer.dart) example.

### Result

All `analyze` methods return a `SensitivityAnalysisResult` object:

```dart
class SensitivityAnalysisResult {
  final bool isSensitive;
  final List<String> detectedTypes; // Available on iOS 27.0+ / macOS 27.0+
}
```

- `isSensitive` — whether the content was flagged as sensitive
- `detectedTypes` — list of detected content categories, e.g. `"sexuallyExplicit"` or `"goreOrViolence"`. Empty on devices running below iOS 27.0 / macOS 27.0.

---

### Caveats

Unlike with other ML models, the SensitiveContentAnalysis Framework:

- Does not return a list of probabilities.
- Does not allow additional training and finetuning.
- Is not open source.
- Only works with Apple devices. (iOS 17.0+, macOS 14.0+, Mac Catalyst 17.0+, iPadOS 17.0+)

---

_Notice:_ _This package was initally created to be used in-house, as such the
development is first and foremost aligned with the internal requirements._
