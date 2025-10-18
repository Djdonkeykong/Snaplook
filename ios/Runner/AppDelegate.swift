import UIKit
import Flutter
import receive_sharing_intent

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let shareStatusChannelName = "com.snaplook.snaplook/share_status"
  private let shareConfigChannelName = "snaplook/share_config"
  private let processingStatusKey = "ShareProcessingStatus"
  private let processingSessionKey = "ShareProcessingSession"
  private let scrapingBeeApiKeyKey = "ScrapingBeeApiKey"
  private let serpApiKeyKey = "SerpApiKey"
  private let detectorEndpointKey = "DetectorEndpoint"
  private let shareLogsChannelName = "snaplook/share_extension_logs"
  private let shareLogsKey = "ShareExtensionLogEntries"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

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

          NSLog("[ShareConfig] ✅ Saved to app group \(appGroupId)")
          NSLog("[ShareConfig] ✅ SerpApiKey: \(serpKey.prefix(8))...")
          NSLog("[ShareConfig] ✅ DetectorEndpoint: \(endpoint)")

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

  private func sharedUserDefaults() -> UserDefaults? {
    let defaultGroupId = "group.\(Bundle.main.bundleIdentifier ?? "")"
    if let customGroupId = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String,
       !customGroupId.isEmpty,
       customGroupId != "$(CUSTOM_GROUP_ID)" {
      return UserDefaults(suiteName: customGroupId)
    }
    return UserDefaults(suiteName: defaultGroupId)
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
