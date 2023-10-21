# WIP! Sensitive Content Analysis

#### Provide a safer experience in your app by detecting and alerting users to nudity in images and videos before displaying them onscreen.

<img src="https://docs-assets.developer.apple.com/published/36d145c8a9/renderedDark2x-1684208404.png" width="500px"/>
<img src="https://docs-assets.developer.apple.com/published/57e2efdd76/rendered2x-1692659569.png" width="500px" />

[![Pub](https://img.shields.io/pub/v/sensitive_content_analysis.svg?style=popout&include_prereleases)](https://pub.dev/packages/sensitive_content_analysis)

Dart package for interacting with Apple's
[SensitiveContentAnalysis Framework](https://developer.apple.com/documentation/sensitivecontentanalysis).

#### Minimum requirements

iOS/iPadOS `>=17.0+`

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

## Usage

#### Analyze File Image:

```dart
  try {
    final sca = SensitiveContentAnalysis.instance;
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

    } catch (e) {
        return null;
    }
  }
```

#### Analyze Network Image:

##### Install the test profile

For testing purposes Apple provides a test profile with which you can test the
QR code, without having to install actual NSFW content.

<img src="https://docs-assets.developer.apple.com/published/517e263450/rendered2x-1685188934.png" width="120px" />

See:
https://developer.apple.com/documentation/sensitivecontentanalysis/testing_your_app_s_response_to_sensitive_media

```dart
final String? analyzeUrl = "https://docs-assets.developer.apple.com/published/517e263450/rendered2x-1685188934.png";

  try {
    final sca = SensitiveContentAnalysis.instance;

    if (analyzeUrl != null) {
        // Analyze the network image for sensitive content.
        final bool? isSensitive = await sca.analyzeNetworkImage(url: analyzeUrl);
        if (isSensitive != null) {
            return isSensitive;
        } else {
            debugPrint("Enable ”Sensitive Content Warning” in Settings -> Privacy & Security.");
            return null;
        }

    } catch (e) {
        return null;
    }
  }
```

#### Analyze Video:

- todo

---

_Notice:_ _This package was initally created to be used in-house, as such the
development is first and foremost aligned with the internal requirements._
