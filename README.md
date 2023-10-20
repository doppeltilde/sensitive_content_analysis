# WIP! Sensitive Content Analysis

[![Pub](https://img.shields.io/pub/v/sensitive_content_analysis.svg?style=popout&include_prereleases)](https://pub.dev/packages/sensitive_content_analysis)

Dart package for interacting with Apple's
[SensitiveContentAnalysis Framework](https://developer.apple.com/documentation/sensitivecontentanalysis).

#### Minimum requirements

iOS/iPadOS `>=17.0+`

---

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
        }
    } catch (e) {
        return false;
    }
  }
```

#### Analyze Network Image:

- todo

#### Analyze Video:

- todo

---

_Notice:_ _This package was initally created to be used in-house, as such the
development is first and foremost aligned with the internal requirements._
