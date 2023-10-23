import SensitiveContentAnalysis

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
 		let channel = FlutterMethodChannel(name: "sensitive_content_analysis", binaryMessenger: registrar.messenger())
 	    #else
 		let channel = FlutterMethodChannel(name: "sensitive_content_analysis", binaryMessenger: registrar.messenger)
 	    #endif
        let instance = SensitiveContentAnalysisPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    @available(iOS 17.0, macOS 14.0, *)
    private func analyzeImage(image: FlutterStandardTypedData, result: @escaping (Bool?, Error?) -> Void) {
        Task {
            do {
                let analyzer = try SCSensitivityAnalyzer()
                let policy = analyzer.analysisPolicy

                if policy == .disabled {
                    return result(nil, nil)
                } else {
                    #if os(iOS)
                    guard let uiImage = UIImage(data: image.data) else {
                        return result(nil, nil)
                    }

                    if let cgImage = uiImage.cgImage {
                        let analysisResult = try await analyzer.analyzeImage(cgImage)
                        let isSensitive = analysisResult.isSensitive
                        return result(isSensitive, nil)
                    }
                    #elseif os(macOS)
                    guard let nsImage = NSImage(data: image.data) else {
                        return result(nil, nil)
                    }

                    if let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        let analysisResult = try await analyzer.analyzeImage(cgImage)
                        let isSensitive = analysisResult.isSensitive
                        return result(isSensitive, nil)
                    }
                    #endif
                }
            } catch let error {
                return result(nil, error)
            }
        }
    }


    @available(iOS 17.0, macOS 14.0, *)
    private func analyzeNetworkImage(at fileURL: URL, result: @escaping (Bool?, Error?) -> Void) {
        Task {
            do {
                let analyzer = try SCSensitivityAnalyzer()
                let policy = analyzer.analysisPolicy

                if policy == .disabled {
                    result(nil, nil)
                } else {
                    #if os(iOS)
                    if let data = try? Data(contentsOf: fileURL),
                    let uiImage = UIImage(data: data),
                    let cgImage = uiImage.cgImage {
                        let analysisResult = try await analyzer.analyzeImage(cgImage)
                        let isSensitive = analysisResult.isSensitive
                        result(isSensitive, nil)
                    } else {
                        result(nil, nil)
                    }
                    #elseif os(macOS)
                    if let data = try? Data(contentsOf: fileURL),
                    let nsImage = NSImage(data: data) {
                        if let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                            let analysisResult = try await analyzer.analyzeImage(cgImage)
                            let isSensitive = analysisResult.isSensitive
                            result(isSensitive, nil)
                        }
                    } else {
                        result(nil, nil)
                    }
                    #endif
                }
            } catch let error {
                result(nil, error)
            }
        }
    }


    @available(iOS 17.0, macOS 14.0, *)
    private func checkPolicy(result: @escaping (Int?, Error?) -> Void) {
        let analyzer = try SCSensitivityAnalyzer()
        // Check the current analysis policy. 
        let policy = analyzer.analysisPolicy
        if policy == .disabled { return result(0, nil) } 
        else if policy == .simpleInterventions {
            return result(1, nil)
        } else if policy == .descriptiveInterventions {
            return result(2, nil)
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 17.0, macOS 14.0, *) {
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
                guard let image = call.arguments as? FlutterStandardTypedData else {
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
        
            case "checkPolicy":
                checkPolicy { policyResult, error in
                    if let error = error {
                        result(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
                    } else if let policyResult = policyResult {
                        result(policyResult)
                    } else {
                        result(FlutterError(code: "UNEXPECTED_ERROR", message: "Unexpected error occurred", details: nil))
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