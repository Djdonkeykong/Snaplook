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

        print("[APPDELEGATE] app:open:url called - URL: \(url)")
        print("[APPDELEGATE] URL scheme: \(url.scheme ?? "nil")")
        print("[APPDELEGATE] URL host: \(url.host ?? "nil")")

        // Handle custom URL scheme (snaplook://share)
        if url.scheme == "snaplook" && url.host == "share" {
            print("[APPDELEGATE] Recognized snaplook://share URL scheme!")
            print("[APPDELEGATE] Will notify Flutter in 0.5 seconds")

            // Notify Flutter that shared data is available
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                print("[APPDELEGATE] Notifying Flutter of shared data")
                self?.notifyFlutterOfSharedData()
            }
            return true
        }

        print("[APPDELEGATE] URL scheme not recognized, passing to super")
        return super.application(app, open: url, options: options)
    }

    private func getSharedDataFromAppGroup() -> [String: Any]? {
        print("[APPDELEGATE] getSharedDataFromAppGroup called")

        guard let userDefaults = UserDefaults(suiteName: appGroupName) else {
            print("[APPDELEGATE ERROR] Failed to access UserDefaults with suite: \(appGroupName)")
            return nil
        }

        print("[APPDELEGATE] Successfully accessed UserDefaults")

        var sharedData: [String: Any] = [:]

        // Check for shared image
        if let imageData = userDefaults.data(forKey: "shared_image") {
            print("[APPDELEGATE] Found shared_image - size: \(imageData.count) bytes")
            let base64String = imageData.base64EncodedString()
            sharedData["image"] = base64String
            sharedData["type"] = "image"
            print("[APPDELEGATE] Encoded image to base64")
        } else {
            print("[APPDELEGATE] No shared_image found")
        }

        // Check for shared URL
        if let urlString = userDefaults.string(forKey: "shared_url") {
            print("[APPDELEGATE] Found shared_url: \(urlString)")
            sharedData["url"] = urlString
            sharedData["type"] = "url"
        } else {
            print("[APPDELEGATE] No shared_url found")
        }

        // Check timestamp
        if let timestamp = userDefaults.object(forKey: "shared_timestamp") as? Double {
            print("[APPDELEGATE] Found timestamp: \(timestamp)")
            sharedData["timestamp"] = timestamp
        } else {
            print("[APPDELEGATE] No timestamp found")
        }

        let isEmpty = sharedData.isEmpty
        print("[APPDELEGATE] Shared data isEmpty: \(isEmpty)")
        return isEmpty ? nil : sharedData
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
        print("[APPDELEGATE] notifyFlutterOfSharedData called")
        print("[APPDELEGATE] methodChannel exists: \(methodChannel != nil)")
        methodChannel?.invokeMethod("onSharedData", arguments: nil)
        print("[APPDELEGATE] Invoked onSharedData on Flutter side")
    }
}
