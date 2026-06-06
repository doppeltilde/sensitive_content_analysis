#if canImport(SensitiveContentAnalysis)
  import SensitiveContentAnalysis
#endif

#if os(iOS)
  import Flutter
  import UIKit
#else
  import FlutterMacOS
  import AppKit
#endif

public class SensitiveContentAnalysisPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif

    let channel = FlutterMethodChannel(
      name: "sensitive_content_analysis",
      binaryMessenger: messenger
    )

    let instance = SensitiveContentAnalysisPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private var _analyzer: Any?

  @available(iOS 17.0, macOS 14.0, *)
  private var analyzer: SCSensitivityAnalyzer {
    if let existing = _analyzer as? SCSensitivityAnalyzer {
      return existing
    }

    let newAnalyzer = SCSensitivityAnalyzer()
    _analyzer = newAnalyzer
    return newAnalyzer
  }

  private func cgImage(from data: Data) -> CGImage? {
    #if os(iOS)
      return UIImage(data: data)?.cgImage
    #elseif os(macOS)
      guard let nsImage = NSImage(data: data) else { return nil }
      var imageRect = CGRect(
        x: 0, y: 0, width: nsImage.size.width, height: nsImage.size.height)
      return nsImage.cgImage(
        forProposedRect: &imageRect,
        context: nil,
        hints: nil
      )
    #endif
  }

  @available(iOS 17.0, macOS 14.0, *)
  private func analyzeImage(
    image: FlutterStandardTypedData,
    result: @escaping FlutterResult
  ) {
    Task(priority: .userInitiated) {
      let analyzer = await MainActor.run { self.analyzer }

      guard analyzer.analysisPolicy != .disabled else {
        await MainActor.run { result(nil) }
        return
      }

      guard let cgImage = cgImage(from: image.data) else {
        await MainActor.run { result(nil) }
        return
      }

      do {
        let analysisResult = try await analyzer.analyzeImage(cgImage)

        await MainActor.run {
          result(analysisResult.isSensitive)
        }
      } catch {
        await MainActor.run {
          result(
            FlutterError(
              code: "analysis_error",
              message: "Failed to analyze image",
              details: error.localizedDescription
            )
          )
        }
      }
    }
  }

  @available(iOS 17.0, macOS 14.0, *)
  private func analyzeVideo(
    at fileURL: URL,
    result: @escaping FlutterResult
  ) {
    Task(priority: .userInitiated) {
      let analyzer = await MainActor.run { self.analyzer }

      guard analyzer.analysisPolicy != .disabled else {
        await MainActor.run { result(nil) }
        return
      }

      do {
        let handler = analyzer.videoAnalysis(forFileAt: fileURL)
        let analysisResult = try await handler.hasSensitiveContent()

        await MainActor.run {
          result(analysisResult.isSensitive)
        }
      } catch {
        await MainActor.run {
          result(
            FlutterError(
              code: "analysis_error",
              message: "Failed to analyze video",
              details: error.localizedDescription
            )
          )
        }
      }
    }
  }

  @available(iOS 17.0, macOS 14.0, *)
  private func analyzeNetworkImage(
    at url: URL,
    result: @escaping FlutterResult
  ) {
    Task(priority: .userInitiated) {
      let analyzer = await MainActor.run { self.analyzer }

      guard analyzer.analysisPolicy != .disabled else {
        await MainActor.run { result(nil) }
        return
      }

      do {
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let cgImage = cgImage(from: data) else {
          await MainActor.run { result(nil) }
          return
        }

        let analysisResult = try await analyzer.analyzeImage(cgImage)

        await MainActor.run {
          result(analysisResult.isSensitive)
        }
      } catch {
        await MainActor.run {
          result(
            FlutterError(
              code: "analysis_error",
              message: "Failed to analyze network image",
              details: error.localizedDescription
            )
          )
        }
      }
    }
  }

  @available(iOS 17.0, macOS 14.0, *)
  private func checkPolicy(result: @escaping FlutterResult) {
    Task { @MainActor in
      let analyzer = self.analyzer
      switch analyzer.analysisPolicy {
      case .disabled:
        result(0)
      case .simpleInterventions:
        result(1)
      case .descriptiveInterventions:
        result(2)
      @unknown default:
        result(
          FlutterError(
            code: "unknown_policy",
            message: "Unrecognized AnalysisPolicy value",
            details: nil
          )
        )
      }
    }
  }

  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard #available(iOS 17.0, macOS 14.0, *) else {
      result(FlutterMethodNotImplemented)
      return
    }

    switch call.method {

    case "analyzeImage":
      guard let image = call.arguments as? FlutterStandardTypedData else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Expected FlutterStandardTypedData for image",
            details: nil
          )
        )
        return
      }
      analyzeImage(image: image, result: result)

    case "analyzeVideo":
      guard
        let args = call.arguments as? [String: Any],
        let urlString = args["url"] as? String,
        let url = URL(string: urlString)
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Expected a valid 'url' string argument",
            details: nil
          )
        )
        return
      }
      analyzeVideo(at: url, result: result)

    case "analyzeNetworkImage":
      guard
        let args = call.arguments as? [String: Any],
        let urlString = args["url"] as? String,
        let url = URL(string: urlString)
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Expected a valid 'url' string argument",
            details: nil
          )
        )
        return
      }
      analyzeNetworkImage(at: url, result: result)

    case "checkPolicy":
      checkPolicy(result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
