import Flutter
import UIKit
import SensitiveContentAnalysis

public class SensitiveContentAnalysisPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "sensitive_content_analysis", binaryMessenger: registrar.messenger())
        let instance = SensitiveContentAnalysisPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    @available(iOS 17.0, *)
    private func analyzeImage(image: UIImage, result: @escaping (Bool?, Error?) -> Void) {
        Task {
            do {
                let analyzer = try SCSensitivityAnalyzer()
                let policy = analyzer.analysisPolicy

                if policy == .disabled {
                    return result(nil, nil)
                } else {
                    guard let cgImage = image.cgImage else {
                        return result(nil, nil)
                    }

                    let analysisResult = try await analyzer.analyzeImage(cgImage)
                    let isSensitive = analysisResult.isSensitive
                    return result(isSensitive, nil)
                }
            } catch let error {
                return result(nil, error)
            }
        }
    }

    @available(iOS 17.0, *)
    private func analyzeNetworkImage(at fileURL: URL, result: @escaping (Bool?, Error?) -> Void) {
        Task {
            do {
                let analyzer = try SCSensitivityAnalyzer()
                let policy = analyzer.analysisPolicy

                if policy == .disabled {
                    result(nil, nil)
                } else {
                    guard let data = try? Data(contentsOf: fileURL),
                        let image = UIImage(data: data),
                        let cgImage = image.cgImage else {
                        result(nil, nil)
                        return
                    }

                    let analysisResult = try await analyzer.analyzeImage(cgImage)
                    let isSensitive = analysisResult.isSensitive
                    result(isSensitive, nil)
                }
            } catch let error {
                result(nil, error)
            }
        }
    }


    @available(iOS 17.0, *)
    private func checkSensitivityAnalysisPolicy(result: @escaping (Bool?, Error?) -> Void) {
        let analyzer = try SCSensitivityAnalyzer()
        // Check the current analysis policy. 
        let policy = analyzer.analysisPolicy
        if policy == .disabled { return result(false, nil) } 
        else if policy == .simpleInterventions {
            return result(true, nil)
        } else if policy == .descriptiveInterventions {
            return result(true, nil)
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 17.0, *) {
            // Handle Flutter method calls
            switch call.method {
            case "analyzeNetworkImage":
                guard let args = call.arguments else {
                    return result(FlutterError(code: "-1", message: "Could not recognize flutter arguments in method: \(call.method)", details: nil))
                }
                if let myArgs = args as? [String: Any],
                let urlString = myArgs["url"] as? String,
                let url = URL(string: urlString) {
                    analyzeNetworkImage(at: url) { isSensitive, error in
                        if let error = error {
                            result(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
                        } else {
                            result(isSensitive)
                        }
                    }
                } else {
                    result(FlutterError(code: "-1", message: "Could not recognize flutter arguments in method: \(call.method)", details: nil))
                }

            case "analyzeImage":
                guard let imageData = call.arguments as? FlutterStandardTypedData,
                    let image = UIImage(data: imageData.data) else {
                    result(FlutterError(code: "invalid_arguments", message: "Invalid image data", details: nil))
                    return
                }
                    analyzeImage(image: image) { isSensitive, error in
                        if let error = error {
                            result(FlutterError(code: "analysis_error", message: "Failed to analyze image", details: error.localizedDescription))
                        } else {
                            result(isSensitive)
                        }
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
}