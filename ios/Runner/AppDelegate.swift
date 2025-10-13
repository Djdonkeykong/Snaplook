import UIKit
import Flutter
import receive_sharing_intent

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let shareStatusChannelName = "com.snaplook.snaplook/share_status"
  private let processingStatusKey = "ShareProcessingStatus"
  private let processingSessionKey = "ShareProcessingSession"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let shareStatusChannel = FlutterMethodChannel(
        name: shareStatusChannelName,
        binaryMessenger: controller.binaryMessenger
      )

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
