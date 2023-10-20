import Flutter
import UIKit
import SensitiveContentAnalysis

public class SensitiveContentAnalysisPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "sensitive_content_analysis", binaryMessenger: registrar.messenger())
        let instance = SensitiveContentAnalysisPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 17.0, *) {
            // Handle Flutter method calls
            switch call.method {
            case "analyzeImageURL":
                result(FlutterMethodNotImplemented)
            case "analyzeImage":
                guard let imageData = call.arguments as? FlutterStandardTypedData,
                       let image = UIImage(data: imageData.data) else {
                    result(FlutterError(code: "invalid_arguments", message: "Invalid image data", details: nil))
                    return
                }
                analyzeImage(image: image) { sensitivityAnalysis, error in
                    if let error = error {
                        result(FlutterError(code: "analysis_error", message: "Failed to analyze image", details: error.localizedDescription))
                    } else {
                        if let analysis = sensitivityAnalysis {
                            result(analysis.isSensitive)
                        } else {
                            result(false)
                        }
                    }
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    @available(iOS 17.0, *)
    private func analyzeImage(image: UIImage, result: @escaping (SCSensitivityAnalysis?, Error?) -> Void) {
        Task {
            do {
                let analyzer = try SCSensitivityAnalyzer()
                let policy = analyzer.analysisPolicy

                if policy == .disabled {
                    return result(nil, nil)
                } else {
                    let analysisResult = try await analyzer.analyzeImage(image.cgImage!)
                    return result(analysisResult, nil)
                }
            } catch let error {
                return result(nil, error)
            }
        }
    }
}
