import CoreVideo
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

  private static var _cachedMessenger: FlutterBinaryMessenger?

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif

    Self._cachedMessenger = messenger

    let channel = FlutterMethodChannel(
      name: "sensitive_content_analysis",
      binaryMessenger: messenger
    )

    let instance = SensitiveContentAnalysisPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  // MARK: - SCSensitivityAnalyzer

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

  // MARK: - SCVideoStreamAnalyzer

  #if os(iOS)
    private var _streamAnalyzers: [String: Any] = [:]
    private var _streamTasks: [String: Any] = [:]
    private var _streamChannels: [String: FlutterEventChannel] = [:]

    @available(iOS 26.0, *)
    private func streamAnalyzer(for uuid: String) -> SCVideoStreamAnalyzer? {
      return _streamAnalyzers[uuid] as? SCVideoStreamAnalyzer
    }
  #endif

  // MARK: - Helpers

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

    var shouldIndicateSensitivity = false
    var shouldInterruptVideo = false
    var shouldMuteAudio = false

    #if compiler(>=6.2)
      if #available(iOS 26.0, macOS 26.0, *) {
        shouldIndicateSensitivity = analysisResult.shouldIndicateSensitivity
        shouldInterruptVideo = analysisResult.shouldInterruptVideo
        shouldMuteAudio = analysisResult.shouldMuteAudio
      }
    #endif

    return [
      "isSensitive": analysisResult.isSensitive,
      "detectedTypes": detectedTypesArray,
      "shouldIndicateSensitivity": shouldIndicateSensitivity,
      "shouldInterruptVideo": shouldInterruptVideo,
      "shouldMuteAudio": shouldMuteAudio,
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

  #if os(iOS)
    // MARK: - SCVideoStreamAnalyzer lifecycle

    /// Creates an SCVideoStreamAnalyzer for a participant and begins
    /// forwarding `analysisChanges` events back to Dart via the event sink.
    ///
    /// Arguments (Map):
    ///   "participantUUID" : String – stable ID for this stream
    ///   "streamDirection" : Int – 0 = outgoing, 1 = incoming
    ///   "eventChannelName": String – name of the FlutterEventChannel to send updates on

    @available(iOS 26.0, *)
    private func createVideoStreamAnalyzer(
      args: [String: Any],
      result: @escaping FlutterResult,
      messenger: FlutterBinaryMessenger
    ) {
      guard
        let participantUUID = args["participantUUID"] as? String,
        let directionRaw = args["streamDirection"] as? Int,
        let eventChannelName = args["eventChannelName"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message:
              "Expected participantUUID (String), streamDirection (Int), eventChannelName (String)",
            details: nil
          ))
        return
      }

      let direction: SCVideoStreamAnalyzer.StreamDirection =
        directionRaw == 0 ? .outgoing : .incoming

      do {
        let streamAnalyzer = try SCVideoStreamAnalyzer(
          participantUUID: participantUUID,
          streamDirection: direction
        )
        _streamAnalyzers[participantUUID] = streamAnalyzer

        let handler = VideoStreamEventHandler(
          streamAnalyzer: streamAnalyzer,
          formatResult: { [weak self] analysis -> [String: Any]? in
            guard let self else { return nil }
            return self.formatAnalysisResult(analysis)
          }
        )
        let eventChannel = FlutterEventChannel(
          name: eventChannelName,
          binaryMessenger: messenger
        )
        eventChannel.setStreamHandler(handler)

        _streamTasks[participantUUID] = handler
        _streamChannels[participantUUID] = eventChannel

        result(nil)
      } catch {
        result(
          FlutterError(
            code: "stream_analyzer_init_error",
            message:
              "Failed to create SCVideoStreamAnalyzer — ensure Communication Safety or Sensitive Content Warnings is enabled",
            details: error.localizedDescription
          ))
      }
    }

    /// Passes a raw CVPixelBuffer (sent as BGRA bytes + width + height) to
    /// `analyze(_:)` for apps that decode their own video stream.
    ///
    /// Arguments (Map):
    ///   "participantUUID": String
    ///   "bytes"          : FlutterStandardTypedData  – BGRA pixel data
    ///   "width"          : Int
    ///   "height"         : Int
    @available(iOS 26.0, *)
    private func analyzeVideoStreamFrame(
      args: [String: Any],
      result: @escaping FlutterResult
    ) {
      guard
        let participantUUID = args["participantUUID"] as? String,
        let typedData = args["bytes"] as? FlutterStandardTypedData,
        let width = args["width"] as? Int,
        let height = args["height"] as? Int,
        let bytesPerRow = args["bytesPerRow"] as? Int,
        let streamAnalyzer = streamAnalyzer(for: participantUUID)
      else {
        result(
          FlutterError(
            code: "invalid_arguments", message: "Missing required arguments", details: nil))
        return
      }

      let data = typedData.data

      var pixelBuffer: CVPixelBuffer?
      let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        nil,
        &pixelBuffer
      )

      guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
        result(
          FlutterError(
            code: "pixel_buffer_error", message: "Failed to create CVPixelBuffer",
            details: "Status: \(status)"))
        return
      }

      CVPixelBufferLockBaseAddress(buffer, .readOnly)
      defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

      if let dest = CVPixelBufferGetBaseAddress(buffer) {
        let destBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let srcBytesPerRow = bytesPerRow

        data.withUnsafeBytes { srcPtr in
          guard let src = srcPtr.baseAddress else { return }
          for y in 0..<height {
            let srcRow = src.advanced(by: y * srcBytesPerRow)
            let destRow = dest.advanced(by: y * destBytesPerRow)
            memcpy(destRow, srcRow, min(srcBytesPerRow, destBytesPerRow))
          }
        }
      }

      print("📤 [Native] Analyzing frame: \(width)x\(height), bytes: \(data.count)")

      streamAnalyzer.analyze(buffer)
      print(
        "📤 [Native] Frame submitted. Current analysis state: \(streamAnalyzer.analysis?.isSensitive ?? false ? "SENSITIVE" : "SAFE")"
      )
      result(nil)
    }

    /// Tells the analyzer the app is ready to resume after an interruption.
    ///
    /// Arguments (Map):
    ///   "participantUUID": String
    @available(iOS 26.0, *)
    private func continueVideoStream(
      args: [String: Any],
      result: @escaping FlutterResult
    ) {
      guard
        let participantUUID = args["participantUUID"] as? String,
        let streamAnalyzer = streamAnalyzer(for: participantUUID)
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Expected participantUUID and an existing analyzer",
            details: nil
          ))
        return
      }

      streamAnalyzer.continueStream()
      result(nil)
    }

    /// Stops analysis and removes the analyzer for a participant.
    ///
    /// Arguments (Map):
    ///   "participantUUID": String
    @available(iOS 26.0, *)
    private func endVideoStreamAnalysis(
      args: [String: Any],
      result: @escaping FlutterResult
    ) {
      guard
        let participantUUID = args["participantUUID"] as? String,
        let streamAnalyzer = streamAnalyzer(for: participantUUID)
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Expected participantUUID and an existing analyzer",
            details: nil
          ))
        return
      }

      streamAnalyzer.endAnalysis()
      _streamAnalyzers.removeValue(forKey: participantUUID)
      _streamTasks.removeValue(forKey: participantUUID)
      if let eventChannel = _streamChannels[participantUUID] {
        eventChannel.setStreamHandler(nil)
        _streamChannels.removeValue(forKey: participantUUID)
      }
      result(nil)
    }

    // MARK: - VideoStreamEventHandler

    @available(iOS 26.0, *)
    private class VideoStreamEventHandler: NSObject, FlutterStreamHandler {
      private let streamAnalyzer: SCVideoStreamAnalyzer
      private let formatResult: (SCSensitivityAnalysis) -> [String: Any]?
      private var monitorTask: Task<Void, Never>?

      init(
        streamAnalyzer: SCVideoStreamAnalyzer,
        formatResult: @escaping (SCSensitivityAnalysis) -> [String: Any]?
      ) {
        self.streamAnalyzer = streamAnalyzer
        self.formatResult = formatResult
      }

      func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
      ) -> FlutterError? {
        monitorTask?.cancel()

        let analyzer = self.streamAnalyzer
        let formatter = self.formatResult

        print("🔄 [Native] Starting analysisChanges listener...")

        monitorTask = Task { [weak self] in
          guard let self else { return }

          print("▶️ [Native] Task started, waiting for analysisChanges...")

          do {
            for try await analysis in self.streamAnalyzer.analysisChanges {
              print("📡 [Native] >>> analysisChanges EMITTED! isSensitive: \(analysis.isSensitive)")
              guard !Task.isCancelled else {
                print("⏹️ [Native] Task cancelled during analysisChanges")
                break
              }

              var detectedStr = "[]"
              #if compiler(>=6.4)
                if #available(iOS 27.0, *) {
                  detectedStr = "\(analysis.detectedTypes)"
                }
              #endif

              print(
                """
                📡 [Native] Received analysis event → 
                  isSensitive: \(analysis.isSensitive), 
                  shouldInterrupt: \(analysis.shouldInterruptVideo),
                  detectedTypes: \(detectedStr)
                """)

              if let formatted = formatter(analysis) {
                await MainActor.run {
                  events(formatted)
                }
              }
            }

            print("🔚 [Native] analysisChanges stream ended normally")
            await MainActor.run { events(FlutterEndOfEventStream) }
          } catch {
            print("❌ [Native] analysisChanges error: \(error.localizedDescription)")
            await MainActor.run {
              events(
                FlutterError(
                  code: "stream_analysis_error",
                  message: "Error in analysisChanges stream",
                  details: error.localizedDescription
                ))
            }
          }
        }
        return nil
      }

      func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("🛑 [Native] onCancel called for stream analyzer")
        monitorTask?.cancel()
        monitorTask = nil
        return nil
      }
    }

  #endif

  // MARK: - FlutterPlugin handle

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

    case "createVideoStreamAnalyzer",
      "analyzeVideoStreamFrame",
      "continueVideoStream",
      "endVideoStreamAnalysis":
      #if compiler(>=6.2) && os(iOS)
        if #available(iOS 26.0, *) {
          guard let args = call.arguments as? [String: Any] else {
            result(
              FlutterError(
                code: "invalid_arguments",
                message: "Expected a Map argument",
                details: nil
              ))
            return
          }

          let messenger = SensitiveContentAnalysisPlugin._cachedMessenger!

          switch call.method {
          case "createVideoStreamAnalyzer":
            createVideoStreamAnalyzer(args: args, result: result, messenger: messenger)
          case "analyzeVideoStreamFrame":
            analyzeVideoStreamFrame(args: args, result: result)
          case "continueVideoStream":
            continueVideoStream(args: args, result: result)
          case "endVideoStreamAnalysis":
            endVideoStreamAnalysis(args: args, result: result)
          default:
            result(FlutterMethodNotImplemented)
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      #else
        result(FlutterMethodNotImplemented)
      #endif

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
