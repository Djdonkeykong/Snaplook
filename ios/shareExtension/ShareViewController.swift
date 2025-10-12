import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

// Custom implementation that saves to the App Group used by receive_sharing_intent
// This avoids importing Flutter framework which Share Extensions cannot access
class ShareViewController: UIViewController {

    private let appGroupName = "group.com.snaplook.snaplook"
    private let userDefaultsKey = "RSIShareMedia" // Key used by receive_sharing_intent package

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[SHARE EXTENSION] viewDidLoad - custom implementation")

        view.backgroundColor = .white
        handleSharedContent()
    }

    private func handleSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            print("[SHARE EXTENSION] No attachments found")
            completeRequest()
            return
        }

        print("[SHARE EXTENSION] Found \(attachments.count) attachment(s)")

        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                print("[SHARE EXTENSION] Processing image attachment")
                attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (data, error) in
                    if let error = error {
                        print("[SHARE EXTENSION ERROR] \(error)")
                        self?.completeRequest()
                        return
                    }

                    var imageData: Data?
                    if let url = data as? URL {
                        imageData = try? Data(contentsOf: url)
                    } else if let image = data as? UIImage {
                        imageData = image.jpegData(compressionQuality: 0.8)
                    }

                    if let imageData = imageData {
                        print("[SHARE EXTENSION] Saving image data")
                        self?.saveToAppGroup(imageData: imageData)
                    } else {
                        self?.completeRequest()
                    }
                }
                return
            }
        }

        completeRequest()
    }

    private func saveToAppGroup(imageData: Data) {
        guard let userDefaults = UserDefaults(suiteName: appGroupName) else {
            print("[SHARE EXTENSION ERROR] Cannot access App Group")
            completeRequest()
            return
        }

        // Save in format compatible with receive_sharing_intent package
        let mediaItem: [String: Any] = [
            "path": saveImageToTempDirectory(imageData: imageData),
            "type": 0, // 0 = image
            "thumbnail": NSNull(),
            "duration": NSNull(),
            "mimeType": "image/jpeg"
        ]

        var mediaList = userDefaults.array(forKey: userDefaultsKey) as? [[String: Any]] ?? []
        mediaList.append(mediaItem)
        userDefaults.set(mediaList, forKey: userDefaultsKey)
        userDefaults.synchronize()

        print("[SHARE EXTENSION] Saved to App Group")
        openMainApp()
    }

    private func saveImageToTempDirectory(imageData: Data) -> String {
        let fileName = "share_\(UUID().uuidString).jpg"
        let fileURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)!
            .appendingPathComponent(fileName)

        try? imageData.write(to: fileURL)
        return fileURL.path
    }

    private func openMainApp() {
        // Use the ShareMedia URL scheme that receive_sharing_intent expects
        let bundleIdentifier = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String ?? ""
        let url = URL(string: "ShareMedia-\(bundleIdentifier.replacingOccurrences(of: ".shareExtension", with: ""))://")!

        print("[SHARE EXTENSION] Opening main app: \(url)")

        if let extensionContext = self.extensionContext {
            extensionContext.open(url, completionHandler: { [weak self] success in
                print("[SHARE EXTENSION] Open result: \(success)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self?.completeRequest()
                }
            })
        } else {
            completeRequest()
        }
    }

    private func completeRequest() {
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
