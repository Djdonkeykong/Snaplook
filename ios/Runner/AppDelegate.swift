import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {

    private let appGroupName = "group.com.snaplook.snaplook"
    private var methodChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        let controller = window?.rootViewController as! FlutterViewController

        // Set up method channel for sharing data
        methodChannel = FlutterMethodChannel(
            name: "com.snaplook.snaplook/share",
            binaryMessenger: controller.binaryMessenger
        )

        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }

            if call.method == "getSharedData" {
                if let sharedData = self.getSharedDataFromAppGroup() {
                    result(sharedData)
                } else {
                    result(nil)
                }
            } else if call.method == "clearSharedData" {
                self.clearSharedDataFromAppGroup()
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {

        // Handle custom URL scheme (snaplook://share)
        if url.scheme == "snaplook" && url.host == "share" {
            // Notify Flutter that shared data is available
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.notifyFlutterOfSharedData()
            }
            return true
        }

        return super.application(app, open: url, options: options)
    }

    private func getSharedDataFromAppGroup() -> [String: Any]? {
        guard let userDefaults = UserDefaults(suiteName: appGroupName) else {
            return nil
        }

        var sharedData: [String: Any] = [:]

        // Check for shared image
        if let imageData = userDefaults.data(forKey: "shared_image") {
            let base64String = imageData.base64EncodedString()
            sharedData["image"] = base64String
            sharedData["type"] = "image"
        }

        // Check for shared URL
        if let urlString = userDefaults.string(forKey: "shared_url") {
            sharedData["url"] = urlString
            sharedData["type"] = "url"
        }

        // Check timestamp
        if let timestamp = userDefaults.object(forKey: "shared_timestamp") as? Double {
            sharedData["timestamp"] = timestamp
        }

        return sharedData.isEmpty ? nil : sharedData
    }

    private func clearSharedDataFromAppGroup() {
        guard let userDefaults = UserDefaults(suiteName: appGroupName) else {
            return
        }

        userDefaults.removeObject(forKey: "shared_image")
        userDefaults.removeObject(forKey: "shared_url")
        userDefaults.removeObject(forKey: "shared_timestamp")
        userDefaults.synchronize()
    }

    private func notifyFlutterOfSharedData() {
        methodChannel?.invokeMethod("onSharedData", arguments: nil)
    }
}
