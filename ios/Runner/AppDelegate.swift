import UIKit
import Flutter
import receive_sharing_intent
import AVKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let shareStatusChannelName = "com.snaplook.snaplook/share_status"
  private let shareConfigChannelName = "snaplook/share_config"
  private let authChannelName = "snaplook/auth"
  private let processingStatusKey = "ShareProcessingStatus"
  private let processingSessionKey = "ShareProcessingSession"
  private let scrapingBeeApiKeyKey = "ScrapingBeeApiKey"
  private let serpApiKeyKey = "SerpApiKey"
  private let detectorEndpointKey = "DetectorEndpoint"
  private let shareLogsChannelName = "snaplook/share_extension_logs"
  private let shareLogsKey = "ShareExtensionLogEntries"
  private let authFlagKey = "user_authenticated"
  private let authUserIdKey = "supabase_user_id"
  private let pipTutorialChannelName = "pip_tutorial"
  private var pipTutorialManager: PipTutorialManager?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Set window background to black (shows when app is backgrounded)
    window?.backgroundColor = UIColor.black

    if let controller = window?.rootViewController as? FlutterViewController {
      // Share status channel
      let shareStatusChannel = FlutterMethodChannel(
        name: shareStatusChannelName,
        binaryMessenger: controller.binaryMessenger
      )

      // Share config channel
      let shareConfigChannel = FlutterMethodChannel(
        name: shareConfigChannelName,
        binaryMessenger: controller.binaryMessenger
      )

      let shareLogsChannel = FlutterMethodChannel(
        name: shareLogsChannelName,
        binaryMessenger: controller.binaryMessenger
      )

      let authChannel = FlutterMethodChannel(
        name: authChannelName,
        binaryMessenger: controller.binaryMessenger
      )

      let pipTutorialChannel = FlutterMethodChannel(
        name: pipTutorialChannelName,
        binaryMessenger: controller.binaryMessenger
      )

      // Handle auth method calls
      authChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate released", details: nil))
          return
        }

        switch call.method {
        case "setAuthFlag":
          NSLog("[Auth] setAuthFlag called from Flutter")

          guard let args = call.arguments as? [String: Any],
                let isAuthenticated = args["isAuthenticated"] as? Bool else {
            NSLog("[Auth] ERROR: Invalid arguments - isAuthenticated missing")
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
          }

          guard let defaults = self.sharedUserDefaults() else {
            NSLog("[Auth] ERROR: Could not get sharedUserDefaults")
            result(FlutterError(code: "NO_DEFAULTS", message: "Cannot access UserDefaults", details: nil))
            return
          }

          // Log which app group we're using
          let groupId = self.getAppGroupId()
          NSLog("[Auth] Using app group: \(groupId ?? "nil")")

          defaults.set(isAuthenticated, forKey: self.authFlagKey)

          // Store user ID if authenticated
          if let userId = args["userId"] as? String {
            defaults.set(userId, forKey: self.authUserIdKey)
            NSLog("[Auth] Set auth flag to: \(isAuthenticated), userId: \(userId)")
          } else {
            defaults.removeObject(forKey: self.authUserIdKey)
            NSLog("[Auth] Set auth flag to: \(isAuthenticated), userId: nil")
          }

          defaults.synchronize()

          // Verify it was written
          let readBack = defaults.string(forKey: self.authUserIdKey)
          NSLog("[Auth] Verification - read back userId: \(readBack ?? "nil")")

          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      // Handle share config method calls
      shareConfigChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate released", details: nil))
          return
        }

        switch call.method {
        case "saveSharedConfig":
          guard let args = call.arguments as? [String: Any],
                let appGroupId = args["appGroupId"] as? String,
                let serpKey = args["serpApiKey"] as? String,
                let endpoint = args["detectorEndpoint"] as? String,
                let defaults = UserDefaults(suiteName: appGroupId) else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
          }

          defaults.set(serpKey, forKey: self.serpApiKeyKey)
          defaults.set(endpoint, forKey: self.detectorEndpointKey)
          defaults.synchronize()

          NSLog("[ShareConfig] âœ… Saved to app group \(appGroupId)")
          NSLog("[ShareConfig] âœ… SerpApiKey: \(serpKey.prefix(8))...")
          NSLog("[ShareConfig] âœ… DetectorEndpoint: \(endpoint)")

          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      shareStatusChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(
            FlutterError(
              code: "UNAVAILABLE",
              message: "AppDelegate released",
              details: nil
            )
          )
          return
        }

        switch call.method {
        case "configureShareExtension":
          guard let defaults = self.sharedUserDefaults() else {
            result(nil)
            return
          }
          if let args = call.arguments as? [String: Any],
             let apiKey = args["scrapingBeeApiKey"] as? String {
            if apiKey.isEmpty {
              defaults.removeObject(forKey: self.scrapingBeeApiKeyKey)
            } else {
              defaults.set(apiKey, forKey: self.scrapingBeeApiKeyKey)
            }
            defaults.synchronize()
          }
          result(nil)
        case "updateShareProcessingStatus":
          guard
            let args = call.arguments as? [String: Any],
            let status = args["status"] as? String,
            let defaults = self.sharedUserDefaults()
          else {
            result(nil)
            return
          }
          defaults.set(status, forKey: self.processingStatusKey)
          defaults.synchronize()
          result(nil)
        case "markShareProcessingComplete":
          guard let defaults = self.sharedUserDefaults() else {
            result(nil)
            return
          }
          defaults.set("completed", forKey: self.processingStatusKey)
          defaults.synchronize()
          result(nil)
        case "getShareProcessingSession":
          guard let defaults = self.sharedUserDefaults() else {
            result(nil)
            return
          }
          let session = defaults.string(forKey: self.processingSessionKey)
          let status = defaults.string(forKey: self.processingStatusKey)
          var response: [String: Any] = [:]
          response["sessionId"] = session ?? NSNull()
          response["status"] = status ?? NSNull()
          result(response)
        case "getPendingSearchId":
          guard let defaults = self.sharedUserDefaults() else {
            result(nil)
            return
          }
          let searchId = defaults.string(forKey: "search_id")
          if let searchId = searchId {
            NSLog("[ShareExtension] Found pending search_id: \(searchId)")
            defaults.removeObject(forKey: "search_id")
            defaults.synchronize()
          }
          result(searchId)
        case "getPendingPlatformType":
          guard let defaults = self.sharedUserDefaults() else {
            result(nil)
            return
          }
          let platformType = defaults.string(forKey: "pending_platform_type")
          if let platformType = platformType {
            NSLog("[ShareExtension] Found pending platform_type: \(platformType)")
            defaults.removeObject(forKey: "pending_platform_type")
            defaults.synchronize()
          }
          result(platformType)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      shareLogsChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(
            FlutterError(
              code: "UNAVAILABLE",
              message: "AppDelegate released",
              details: nil
            )
          )
          return
        }

        guard let defaults = self.sharedUserDefaults() else {
          result(FlutterError(code: "NO_APP_GROUP", message: "App group not configured", details: nil))
          return
        }

        switch call.method {
        case "getLogs":
          let logs = defaults.stringArray(forKey: self.shareLogsKey) ?? []
          result(logs)
        case "clearLogs":
          defaults.removeObject(forKey: self.shareLogsKey)
          defaults.synchronize()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      pipTutorialChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(
            FlutterError(
              code: "UNAVAILABLE",
              message: "AppDelegate released",
              details: nil
            )
          )
          return
        }

        switch call.method {
        case "start":
          self.appendShareLog("[PiP] Flutter requested tutorial start")
          guard let args = call.arguments as? [String: Any],
                let target = args["target"] as? String else {
            self.appendShareLog("[PiP] ERROR missing target argument")
            result(
              FlutterError(
                code: "INVALID_ARGS",
                message: "Missing target",
                details: nil
              )
            )
            return
          }
          let videoName: String
          if let provided = args["video"] as? String {
            videoName = provided
          } else {
            videoName = (target == "instagram")
              ? "assets/videos/instagram-tutorial.mp4"
              : "assets/videos/pip-test.mp4"
          }
          let assetKey = controller.lookupKey(forAsset: videoName)
          if self.pipTutorialManager == nil {
            self.pipTutorialManager = PipTutorialManager()
            self.pipTutorialManager?.logHandler = { [weak self] msg in
              self?.appendShareLog(msg)
            }
          }
          self.pipTutorialManager?.start(assetKey: assetKey, targetApp: target) { success, errorMsg in
            if success {
              self.appendShareLog("[PiP] Started successfully for target \(target)")
              result(true)
            } else {
              self.appendShareLog("[PiP] FAILED for target \(target): \(errorMsg ?? "unknown error")")
              result(
                FlutterError(
                  code: "PIP_FAILED",
                  message: errorMsg ?? "Unable to start PiP tutorial",
                  details: nil
                )
              )
            }
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let sharingIntent = SwiftReceiveSharingIntentPlugin.instance
    if sharingIntent.hasMatchingSchemePrefix(url: url) {
      return sharingIntent.application(app, open: url, options: options)
    }
    return super.application(app, open: url, options: options)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    pipTutorialManager?.stopIfNeededOnReturn()
  }

  private func getAppGroupId() -> String? {
    let defaultGroupId = "group.\(Bundle.main.bundleIdentifier ?? "")"
    if let customGroupId = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String,
       !customGroupId.isEmpty,
       customGroupId != "$(CUSTOM_GROUP_ID)" {
      return customGroupId
    }
    return defaultGroupId
  }

  private func sharedUserDefaults() -> UserDefaults? {
    return UserDefaults(suiteName: getAppGroupId())
  }

  private func appendShareLog(_ message: String) {
    guard let defaults = sharedUserDefaults() else {
      NSLog("[ShareLogs] Unable to append, missing app group defaults")
      return
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let timestamp = formatter.string(from: Date())
    var entries = defaults.stringArray(forKey: shareLogsKey) ?? []
    entries.append("[\(timestamp)] \(message)")
    if entries.count > 200 {
      entries.removeFirst(entries.count - 200)
    }
    defaults.set(entries, forKey: shareLogsKey)
  }
}

class PipTutorialManager: NSObject {
  private var player: AVPlayer?
  private var playerLayer: AVPlayerLayer?
  private var pipController: AVPictureInPictureController?
  private var stopOnReturn = false
  private var pendingCompletion: ((Bool, String?) -> Void)?
  private var pendingTargetApp: String?
  private weak var hostView: UIView?
  private var pipHasStarted = false
  private var hasOpenedTarget = false
  var logHandler: ((String) -> Void)?

  func start(assetKey: String, targetApp: String, completion: @escaping (Bool, String?) -> Void) {
    // Clean up any previous PiP attempt before starting a new one
    cleanup()

    guard let path = Bundle.main.path(forResource: assetKey, ofType: nil) else {
      logHandler?("[PiP] Video not found at key \(assetKey)")
      completion(false, "Video not found: \(assetKey)")
      return
    }
    let videoUrl = URL(fileURLWithPath: path)
    logHandler?("[PiP] Prepared asset \(assetKey) for target \(targetApp)")

    do {
      let session = AVAudioSession.sharedInstance()
      // Use ambient + mix so other audio keeps playing and we stay silent.
      try session.setCategory(.ambient, mode: .moviePlayback, options: [.mixWithOthers])
      try session.setActive(true)
    } catch {
      NSLog("[PiP] Failed to set audio session: \(error.localizedDescription)")
      logHandler?("[PiP] Audio session setup failed: \(error.localizedDescription)")
    }

    let item = AVPlayerItem(url: videoUrl)
    let player = AVPlayer(playerItem: item)
    player.isMuted = true
    self.player = player

    guard AVPictureInPictureController.isPictureInPictureSupported() else {
      logHandler?("[PiP] Device does not support Picture in Picture")
      completion(false, "Picture in Picture is not supported on this device/simulator.")
      cleanup()
      return
    }

    let layer = AVPlayerLayer(player: player)
    layer.videoGravity = .resizeAspect
    playerLayer = layer

    // Attach the layer to a tiny hosting view so PiP can start reliably
    if let rootView = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap({ $0.windows })
      .first(where: { $0.isKeyWindow })?.rootViewController?.view {
      let host = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
      host.isHidden = true
      rootView.addSubview(host)
      layer.frame = host.bounds
      host.layer.addSublayer(layer)
      hostView = host
    }

    guard let controller = AVPictureInPictureController(playerLayer: layer) else {
      logHandler?("[PiP] Could not create AVPictureInPictureController (nil)")
      completion(false, "Unable to create PiP controller")
      cleanup()
      return
    }
    controller.delegate = self
    if #available(iOS 14.2, *) {
      controller.canStartPictureInPictureAutomaticallyFromInline = true
    }
    pipController = controller

    // Hold onto the completion and target; execute once PiP actually starts
    pendingCompletion = { success, error in
      DispatchQueue.main.async {
        completion(success, error)
      }
    }
    pendingTargetApp = targetApp

    logHandler?("[PiP] Starting PiP for target \(targetApp)")
    player.play()
    controller.startPictureInPicture()

    // Fallback: if the delegate doesn't fire quickly, still open the target app
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.openTargetIfNeeded(reason: "fallback-after-start")
    }
  }

  func stopIfNeededOnReturn() {
    if stopOnReturn {
      stop()
    }
  }

  private func stop() {
    pipController?.stopPictureInPicture()
    cleanup()
    stopOnReturn = false
  }

  private func cleanup() {
    player?.pause()
    player = nil
    playerLayer = nil
    pipController = nil
    pendingCompletion = nil
    pendingTargetApp = nil
    hostView?.removeFromSuperview()
    hostView = nil
    pipHasStarted = false
    hasOpenedTarget = false
  }

  private func complete(_ success: Bool, error: String? = nil) {
    guard let completion = pendingCompletion else { return }
    pendingCompletion = nil
    completion(success, error)
  }

  private func openTargetIfNeeded(reason: String) {
    guard !hasOpenedTarget, let target = pendingTargetApp else { return }
    hasOpenedTarget = true
    guard let url = urlForTarget(target) else {
      logHandler?("[PiP] No URL scheme for target \(target) (\(reason))")
      return
    }
    if UIApplication.shared.canOpenURL(url) {
      logHandler?("[PiP] Opening target app \(target) (\(reason))")
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    } else {
      logHandler?("[PiP] Cannot open target app \(target) - scheme unavailable (\(reason))")
    }
  }

  private func urlForTarget(_ target: String) -> URL? {
    switch target {
    case "instagram":
      return URL(string: "instagram://app")
    case "pinterest":
      return URL(string: "pinterest://")
    case "tiktok":
      return URL(string: "snssdk1233://")
    case "photos":
      return URL(string: "photos-redirect://")
    case "facebook":
      return URL(string: "fb://")
    case "imdb":
      return URL(string: "imdb://")
    case "safari":
      return URL(string: "http://www.google.com")
    case "x":
      return URL(string: "twitter://")
    default:
      return nil
    }
  }
}

extension PipTutorialManager: AVPictureInPictureControllerDelegate {
  func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
    stopOnReturn = true
    pipHasStarted = true
    logHandler?("[PiP] PiP started by system")
    openTargetIfNeeded(reason: "delegate-didStart")
    pendingTargetApp = nil
    complete(true, error: nil)
  }

  func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
    logHandler?("[PiP] PiP failed to start: \(error.localizedDescription)")
    complete(false, error: error.localizedDescription)
    cleanup()
  }

  func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
    stopOnReturn = false
    logHandler?("[PiP] PiP stopped by system")
    cleanup()
  }
}
