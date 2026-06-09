import ImageIO

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
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
  }

  @available(iOS 17.0, macOS 14.0, *)
  private func formatAnalysisResult(_ analysisResult: SCSensitivityAnalysis) -> [String: Any] {
    var detectedTypesArray: [String] = []

    #if compiler(>=6.4)
      if #available(iOS 27.0, macOS 27.0, *) {
        if analysisResult.isSensitive {
          if analysisResult.detectedTypes.contains(.sexuallyExplicit) {
            detectedTypesArray.append("sexuallyExplicit")
          }
          if analysisResult.detectedTypes.contains(.goreOrViolence) {
            detectedTypesArray.append("goreOrViolence")
          }
        }
      }
    #endif

    return [
      "isSensitive": analysisResult.isSensitive,
      "detectedTypes": detectedTypesArray,
    ]
  }

  private actor AnalysisQueue {
    private var running = 0
    private let maxConcurrent = 3
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
      if running < maxConcurrent {
        running += 1
        return
      }
      await withCheckedContinuation { continuation in
        waiters.append(continuation)
      }
    }

    func release() {
      if !waiters.isEmpty {
        let next = waiters.removeFirst()
        next.resume()
      } else {
        running = max(0, running - 1)
      }
    }
  }

  private let queue = AnalysisQueue()

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
          result(self.formatAnalysisResult(analysisResult))
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
          result(self.formatAnalysisResult(analysisResult))
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
      await queue.acquire()
      defer { Task { await queue.release() } }
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
          result(self.formatAnalysisResult(analysisResult))
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
