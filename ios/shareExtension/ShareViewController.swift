import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let appGroupName = "group.com.snaplook.snaplook"
    private var activityIndicator: UIActivityIndicatorView!
    private var messageLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        print("[SHARE EXTENSION] viewDidLoad called")
        setupUI()
        handleSharedContent()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.white

        // Create importing message label
        messageLabel = UILabel()
        messageLabel.text = "Importing..."
        messageLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        messageLabel.textColor = UIColor.black
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)

        // Create activity indicator
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = UIColor(red: 242/255, green: 0/255, blue: 60/255, alpha: 1.0) // Red accent color
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)

        // Layout constraints
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),

            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20)
        ])

        activityIndicator.startAnimating()
    }

    private func handleSharedContent() {
        print("[SHARE EXTENSION] handleSharedContent called")

        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            print("[SHARE EXTENSION] No extension items or attachments found")
            completeRequest()
            return
        }

        print("[SHARE EXTENSION] Found \(attachments.count) attachment(s)")

        for attachment in attachments {
            // Handle images
            if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                print("[SHARE EXTENSION] Found image attachment - loading...")
                attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (data, error) in
                    if let error = error {
                        print("[SHARE EXTENSION ERROR] Error loading image: \(error)")
                        self?.completeRequest()
                        return
                    }

                    print("[SHARE EXTENSION] Image loaded successfully")
                    var imageData: Data?

                    if let url = data as? URL {
                        print("[SHARE EXTENSION] Image data is URL: \(url)")
                        imageData = try? Data(contentsOf: url)
                        print("[SHARE EXTENSION] Loaded data from URL - size: \(imageData?.count ?? 0) bytes")
                    } else if let image = data as? UIImage {
                        print("[SHARE EXTENSION] Image data is UIImage")
                        imageData = image.jpegData(compressionQuality: 0.8)
                        print("[SHARE EXTENSION] Converted to JPEG - size: \(imageData?.count ?? 0) bytes")
                    }

                    if let imageData = imageData {
                        print("[SHARE EXTENSION] Saving shared data with image")
                        self?.saveSharedData(imageData: imageData, url: nil)
                    } else {
                        print("[SHARE EXTENSION ERROR] Failed to get image data")
                        self?.completeRequest()
                    }
                }
                return
            }

            // Handle URLs
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (data, error) in
                    if let error = error {
                        print("Error loading URL: \(error)")
                        self?.completeRequest()
                        return
                    }

                    if let url = data as? URL {
                        self?.saveSharedData(imageData: nil, url: url.absoluteString)
                    } else {
                        self?.completeRequest()
                    }
                }
                return
            }
        }

        completeRequest()
    }

    private func saveSharedData(imageData: Data?, url: String?) {
        print("[SHARE EXTENSION] saveSharedData called")
        print("[SHARE EXTENSION] imageData size: \(imageData?.count ?? 0) bytes")
        print("[SHARE EXTENSION] url: \(url ?? "nil")")

        guard let userDefaults = UserDefaults(suiteName: appGroupName) else {
            print("[SHARE EXTENSION ERROR] Failed to access UserDefaults with suite: \(appGroupName)")
            completeRequest()
            return
        }

        print("[SHARE EXTENSION] Successfully accessed UserDefaults")

        // Save shared data
        if let imageData = imageData {
            print("[SHARE EXTENSION] Saving image data to UserDefaults")
            userDefaults.set(imageData, forKey: "shared_image")
            userDefaults.set(Date().timeIntervalSince1970, forKey: "shared_timestamp")
            print("[SHARE EXTENSION] Image saved successfully")
        }

        if let url = url {
            print("[SHARE EXTENSION] Saving URL to UserDefaults: \(url)")
            userDefaults.set(url, forKey: "shared_url")
            userDefaults.set(Date().timeIntervalSince1970, forKey: "shared_timestamp")
            print("[SHARE EXTENSION] URL saved successfully")
        }

        let synced = userDefaults.synchronize()
        print("[SHARE EXTENSION] UserDefaults synchronized: \(synced)")

        // Open the main app
        print("[SHARE EXTENSION] Will open main app in 0.5 seconds")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            print("[SHARE EXTENSION] Opening main app now")
            self?.openMainApp()
        }
    }

    private func openMainApp() {
        print("[SHARE EXTENSION] openMainApp called")

        // Open the main Snaplook app with custom URL scheme
        let url = URL(string: "snaplook://share")!
        print("[SHARE EXTENSION] Attempting to open URL: \(url)")

        // Use extensionContext.open() which is the proper way for extensions to open URLs
        if let extensionContext = self.extensionContext {
            print("[SHARE EXTENSION] Using extensionContext.open()")
            extensionContext.open(url, completionHandler: { [weak self] success in
                print("[SHARE EXTENSION] extensionContext.open() completed - success: \(success)")
                if success {
                    print("[SHARE EXTENSION] Successfully opened main app!")
                } else {
                    print("[SHARE EXTENSION ERROR] Failed to open main app")
                }

                // Complete the request after opening
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    print("[SHARE EXTENSION] Completing request and closing extension")
                    self?.completeRequest()
                }
            })
        } else {
            print("[SHARE EXTENSION ERROR] No extensionContext available")
            self.completeRequest()
        }
    }

    private func completeRequest() {
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
