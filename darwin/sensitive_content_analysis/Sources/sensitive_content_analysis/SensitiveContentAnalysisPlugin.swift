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

@objc public class SensitiveContentAnalysisPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
            let channel = FlutterMethodChannel(
                name: "sensitive_content_analysis", binaryMessenger: registrar.messenger())
        #else
            let channel = FlutterMethodChannel(
                name: "sensitive_content_analysis", binaryMessenger: registrar.messenger)
        #endif
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
            return NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #endif
    }

    @available(iOS 17.0, macOS 14.0, *)
    private func analyzeImage(image: FlutterStandardTypedData, result: @escaping FlutterResult) {
        Task(priority: .userInitiated) {
            guard analyzer.analysisPolicy != .disabled else {
                return result(nil)
            }
            guard let cgImage = cgImage(from: image.data) else {
                return result(nil)
            }
            do {
                let analysisResult = try await analyzer.analyzeImage(cgImage)
                result(analysisResult.isSensitive)
            } catch {
                result(
                    FlutterError(
                        code: "analysis_error",
                        message: "Failed to analyze image",
                        details: error.localizedDescription))
            }
        }
    }

    @available(iOS 17.0, macOS 14.0, *)
    private func analyzeVideo(at fileURL: URL, result: @escaping FlutterResult) {
        Task(priority: .userInitiated) {
            guard analyzer.analysisPolicy != .disabled else {
                return result(nil)
            }
            do {
                let handler = analyzer.videoAnalysis(forFileAt: fileURL)
                let analysisResult = try await handler.hasSensitiveContent()
                result(analysisResult.isSensitive)
            } catch {
                result(
                    FlutterError(
                        code: "analysis_error",
                        message: "Failed to analyze video",
                        details: error.localizedDescription))
            }
        }
    }

    @available(iOS 17.0, macOS 14.0, *)
    private func analyzeNetworkImage(at url: URL, result: @escaping FlutterResult) {
        Task(priority: .userInitiated) {
            guard analyzer.analysisPolicy != .disabled else {
                return result(nil)
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let cgImage = cgImage(from: data) else {
                    return result(nil)
                }
                let analysisResult = try await analyzer.analyzeImage(cgImage)
                result(analysisResult.isSensitive)
            } catch {
                result(
                    FlutterError(
                        code: "analysis_error",
                        message: "Failed to analyze network image",
                        details: error.localizedDescription))
            }
        }
    }

    @available(iOS 17.0, macOS 14.0, *)
    private func checkPolicy(result: @escaping FlutterResult) {
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
                    details: nil))
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 17.0, macOS 14.0, *) else {
            return result(FlutterMethodNotImplemented)
        }

        // Handle Flutter method calls
        switch call.method {
        case "analyzeImage":
            guard let image = call.arguments as? FlutterStandardTypedData else {
                return result(
                    FlutterError(
                        code: "invalid_arguments",
                        message: "Expected FlutterStandardTypedData for image",
                        details: nil))
            }
            analyzeImage(image: image, result: result)

        case "analyzeVideo":
            guard let args = call.arguments as? [String: Any],
                let urlString = args["url"] as? String,
                let url = URL(string: urlString)
            else {
                return result(
                    FlutterError(
                        code: "invalid_arguments",
                        message: "Expected a valid 'url' string argument",
                        details: nil))
            }
            analyzeVideo(at: url, result: result)

        case "analyzeNetworkImage":
            guard let args = call.arguments as? [String: Any],
                let urlString = args["url"] as? String,
                let url = URL(string: urlString)
            else {
                return result(
                    FlutterError(
                        code: "invalid_arguments",
                        message: "Expected a valid 'url' string argument",
                        details: nil))
            }
            analyzeNetworkImage(at: url, result: result)

        case "checkPolicy":
            checkPolicy(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
