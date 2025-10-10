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
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            completeRequest()
            return
        }

        for attachment in attachments {
            // Handle images
            if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (data, error) in
                    if let error = error {
                        print("Error loading image: \(error)")
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
                        self?.saveSharedData(imageData: imageData, url: nil)
                    } else {
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
        guard let userDefaults = UserDefaults(suiteName: appGroupName) else {
            print("Failed to access UserDefaults")
            completeRequest()
            return
        }

        // Save shared data
        if let imageData = imageData {
            userDefaults.set(imageData, forKey: "shared_image")
            userDefaults.set(Date().timeIntervalSince1970, forKey: "shared_timestamp")
        }

        if let url = url {
            userDefaults.set(url, forKey: "shared_url")
            userDefaults.set(Date().timeIntervalSince1970, forKey: "shared_timestamp")
        }

        userDefaults.synchronize()

        // Open the main app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.openMainApp()
        }
    }

    private func openMainApp() {
        // Open the main Snaplook app with custom URL scheme
        let url = URL(string: "snaplook://share")!
        var responder: UIResponder? = self as UIResponder
        let selector = #selector(openURL(_:))

        while responder != nil {
            if responder!.responds(to: selector) && responder != self {
                responder!.perform(selector, with: url)
                break
            }
            responder = responder?.next
        }

        // Complete the request after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.completeRequest()
        }
    }

    @objc private func openURL(_ url: URL) {
        // This method is called via perform selector
    }

    private func completeRequest() {
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
