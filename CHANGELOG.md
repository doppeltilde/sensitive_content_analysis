## 2.1.0
### Breaking
- `analyzeImage`, `analyzeNetworkImage`, and `analyzeVideo` now return `SensitivityAnalysisResult?` instead of `bool?`.

### Added
- `SensitivityAnalysisResult` with `isSensitive` (bool) and `detectedTypes` (List<String>).
- `detectedTypes` returns detected content categories (e.g. `sexuallyExplicit`, `goreOrViolence`) on iOS 27.0+ / macOS 27.0+. Empty list on older OS versions.

### Fix
- Added a queue to `analyzeNetworkImage` preventing SCA from crashing and returning `null`.

## 2.0.3
- Fix: Add backwards compatibility for cocoapods.

## 2.0.2
- Fix: Data Race & Main Thread Violation

## 2.0.0
- Support for Swift Package Manager.

## 1.1.1
- Feat: `Video Analysis` added.

## 1.0.4
- Added privacy manifest.

## 1.0.2

- Fixed: When handling tasks that could potentially cause an app to hang or
  crash due to long-running operations or heavy computations on the main thread.

## 1.0.0

- Feat: `macOS` Platform.
- Fixes.

## 0.0.7

- Feat: Added `checkPolicy`.
- Fixes.

## 0.0.6

- Feat: Added `analyzeNetworkImage`.
- Fixes.

## 0.0.3

- Fix.

## 0.0.1

- Init.
