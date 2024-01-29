# Sensitive Content Analysis

#### Provide a safer experience in your app by detecting and alerting users to nudity in images and videos before displaying them onscreen.

<img src="https://docs-assets.developer.apple.com/published/36d145c8a9/renderedDark2x-1684208404.png" width="500px"/>
<img src="https://docs-assets.developer.apple.com/published/57e2efdd76/rendered2x-1692659569.png" width="500px" />

[![Pub](https://img.shields.io/pub/v/sensitive_content_analysis.svg?style=popout&include_prereleases)](https://pub.dev/packages/sensitive_content_analysis)

Dart package for interacting with Apple's
[SensitiveContentAnalysis Framework](https://developer.apple.com/documentation/sensitivecontentanalysis).

#### Minimum requirements

Lower deployment versions may be targeted, however, it's important to note that the SCA Framework is exclusively compatible with:
- iOS/iPadOS `>=17.0`
- macOS `>=14.0`

#### Other Notice's

- In order to maintain the package's lightweight nature and grant you complete control over your UI's appearance, this package intentionally refrains from incorporating an overlay or blur feature.
- The framework only works on physical devices. [#3](https://github.com/tiltedcube/sensitive_content_analysis/issues/3)

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
final sca = SensitiveContentAnalysis();

int? policy = await sca.checkPolicy();
if (policy != null) {
  return policy;
}
```
> **case disabled = 0**
> If disabled the framework doesn’t detect nudity. The system disables sensitive content analysis under any of the following conditions:
> - The app lacks the necessary com.apple.developer.sensitivecontentanalysis.client entitlement.
> - Neither the Sensitive Content Warning user preference nor the Communication Safety parental control in Screen Time are active.
> - The user disables the Sensitive Content Warnings toggle in your app’s Settings.

> **case simpleInterventions = 1**
> simpleInterventions indicates that the user enables both of the following:
> - Sensitive Content Warnings user preference
> - Sensitive Content Warnings in your app’s settings
>
> When your app detects nudity under this policy, your app needs to:
> - Keep the intervention minimal by describing the issue briefly and updating your app’s UI unobstructively. For example, consider blurring and annotating the area that otherwise presents the sensitive content versus raising a new fullscreen alert.
> - Intervene on the receipt of sensitve content over the network but allow the app to transmit content over the network unchecked.

> **case descriptiveInterventions = 2**
> descriptiveInterventions indicates that the user enables both of the following:
> - Communication Safety parental control in Screen Time
> - Sensitive Content Warnings in your app’s settings
>
> When your app detects nudity under this policy, your app needs to:
> - Use child-appropriate language, such as broadly understood vocabulary
> - Present an alert that fills the full screen.
> - Intervene on the receipt of sensitve content over a network and before transmitting sensitive content over a network.

### Analyze Image

#### File Image:

```dart
  try {
    final sca = SensitiveContentAnalysis();
    final ImagePicker picker = ImagePicker();

    // Pick an image.
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
        Uint8List imageData = await image.readAsBytes();

        // Analyze the image for sensitive content.
        final bool? isSensitive = await sca.analyzeImage(imageData);
        if (isSensitive != null) {
            return isSensitive;
        } else {
            debugPrint("Enable ”Sensitive Content Warning” in Settings -> Privacy & Security.");
            return null;
        }
    }
  } catch (e) {
      return null;
  }
```

#### Network Image:

```dart
final String? analyzeUrl = "https://docs-assets.developer.apple.com/published/517e263450/rendered2x-1685188934.png";

  try {
    final sca = SensitiveContentAnalysis();

    if (analyzeUrl != null) {
        final bool? isSensitive = await sca.analyzeNetworkImage(url: analyzeUrl);
        if (isSensitive != null) {
            return isSensitive;
        } else {
            debugPrint("Enable ”Sensitive Content Warning” in Settings -> Privacy & Security.");
            return null;
        }
    }
  } catch (e) {
      return null;
  }
```

### Analyze Video

#### Network Video:

```dart
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
        debugPrint("SENSITIVE: $isSensitive");
        await file.delete();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }
```

#### Local Video:

```dart
  Future<void> analyzeLocalVideo() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'video',
        extensions: <String>['mp4', 'mkv', 'avi', 'mov'],
      );
      final XFile? selectedFile =
          await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

      if (selectedFile != null) {
        bool? isSensitive = await sca.analyzeVideo(url: selectedFile.path);
        debugPrint("SENSITIVE: $isSensitive");
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }
```

---

### Apps using:
<a href="https://apps.apple.com/us/app/id6471840114"><img src="https://play-lh.googleusercontent.com/FSXy-5Yz14YlxIcivLwy0dUfdP8iMSSkkArFDNtNvT5KBeQMvHbxbvaXbmnuJI41xOo" width="64px"></img></a>

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
