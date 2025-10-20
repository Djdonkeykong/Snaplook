import UIKit

class ShareViewController: RSIShareViewController {

    // MARK: - UI Components
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let analyzeInAppButton = UIButton(type: .system)
    private let analyzeNowButton = UIButton(type: .system)
    private let disclaimerLabel = UILabel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCustomUI()
    }

    // MARK: - UI Setup
    private func setupCustomUI() {
        // Container view
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Title
        titleLabel.text = "How would you like to\nanalyze this image?"
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = UIColor(red: 28/255, green: 28/255, blue: 37/255, alpha: 1.0)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // Analyze in App Button
        configureButton(
            analyzeInAppButton,
            title: "📱 Analyze in App",
            isPrimary: false,
            action: #selector(analyzeInAppTapped)
        )
        containerView.addSubview(analyzeInAppButton)

        // Analyze Now Button
        configureButton(
            analyzeNowButton,
            title: "⚡ Analyze Now",
            isPrimary: true,
            action: #selector(analyzeNowTapped)
        )
        containerView.addSubview(analyzeNowButton)

        // Disclaimer
        disclaimerLabel.text = "💡 Tip: Analyzing in-app lets you crop the image to use fewer search credits"
        disclaimerLabel.numberOfLines = 0
        disclaimerLabel.textAlignment = .center
        disclaimerLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        disclaimerLabel.textColor = UIColor(red: 107/255, green: 114/255, blue: 128/255, alpha: 1.0)
        disclaimerLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(disclaimerLabel)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Container
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // Title
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),

            // Analyze in App Button
            analyzeInAppButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 32),
            analyzeInAppButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            analyzeInAppButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            analyzeInAppButton.heightAnchor.constraint(equalToConstant: 56),

            // Analyze Now Button
            analyzeNowButton.topAnchor.constraint(equalTo: analyzeInAppButton.bottomAnchor, constant: 12),
            analyzeNowButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            analyzeNowButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            analyzeNowButton.heightAnchor.constraint(equalToConstant: 56),

            // Disclaimer
            disclaimerLabel.topAnchor.constraint(equalTo: analyzeNowButton.bottomAnchor, constant: 24),
            disclaimerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            disclaimerLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            disclaimerLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
    }

    private func configureButton(_ button: UIButton, title: String, isPrimary: Bool, action: Selector) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 28
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)

        if isPrimary {
            // Red primary button
            button.backgroundColor = UIColor(red: 242/255, green: 0/255, blue: 60/255, alpha: 1.0)
            button.setTitleColor(.white, for: .normal)
        } else {
            // White secondary button with border
            button.backgroundColor = .white
            button.setTitleColor(UIColor(red: 28/255, green: 28/255, blue: 37/255, alpha: 1.0), for: .normal)
            button.layer.borderWidth = 1.5
            button.layer.borderColor = UIColor(red: 229/255, green: 231/255, blue: 235/255, alpha: 1.0).cgColor
        }
    }

    // MARK: - Button Actions
    @objc private func analyzeInAppTapped() {
        NSLog("[ShareExtension] User selected: Analyze in App")
        // Trigger the standard redirect flow - user will crop in Snaplook
        didSelectPost()
    }

    @objc private func analyzeNowTapped() {
        NSLog("[ShareExtension] User selected: Analyze Now")

        // Disable button and show loading state
        analyzeNowButton.isEnabled = false
        analyzeNowButton.setTitle("Analyzing...", for: .normal)
        analyzeInAppButton.isEnabled = false

        // Start immediate analysis
        performImmediateAnalysis()
    }

    private func performImmediateAnalysis() {
        // Get the shared image
        guard let firstMedia = sharedMedia.first else {
            NSLog("[ShareExtension] No shared media found")
            showErrorAndDismiss("No image found to analyze")
            return
        }

        // Load the image from the file path
        guard let image = UIImage(contentsOfFile: firstMedia.path) else {
            NSLog("[ShareExtension] Failed to load image from path: \(firstMedia.path)")
            showErrorAndDismiss("Failed to load image")
            return
        }

        NSLog("[ShareExtension] Loaded image: \(image.size.width)x\(image.size.height)")

        // Upload to Cloudinary and call detection API
        uploadAndAnalyze(image: image)
    }

    private func uploadAndAnalyze(image: UIImage) {
        // Convert to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            showErrorAndDismiss("Failed to process image")
            return
        }

        // Convert to base64
        let base64String = imageData.base64EncodedString()

        // Get API endpoint from UserDefaults
        let userDefaults = UserDefaults(suiteName: appGroupId)
        guard let apiEndpoint = userDefaults?.string(forKey: kDetectorEndpoint) else {
            showErrorAndDismiss("API endpoint not configured")
            return
        }

        NSLog("[ShareExtension] Calling API: \(apiEndpoint)")

        // Call detect-and-search API
        callDetectAndSearchAPI(endpoint: apiEndpoint, imageBase64: base64String)
    }

    private func callDetectAndSearchAPI(endpoint: String, imageBase64: String) {
        guard let url = URL(string: endpoint) else {
            showErrorAndDismiss("Invalid API endpoint")
            return
        }

        // Prepare request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "image_base64": imageBase64,
            "max_results_per_garment": 10
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            showErrorAndDismiss("Failed to prepare request")
            return
        }

        // Make API call
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    NSLog("[ShareExtension] API error: \(error.localizedDescription)")
                    self.showErrorAndDismiss("Analysis failed: \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
                    self.showErrorAndDismiss("No response from server")
                    return
                }

                // Parse response
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        NSLog("[ShareExtension] API response received")

                        // Save results to UserDefaults for main app to access
                        let userDefaults = UserDefaults(suiteName: self.appGroupId)
                        userDefaults?.set(data, forKey: "ShareExtensionAnalysisResults")
                        userDefaults?.set(Date().timeIntervalSince1970, forKey: "ShareExtensionAnalysisTimestamp")
                        userDefaults?.synchronize()

                        // Show success and redirect to app
                        self.showSuccessAndRedirect(resultCount: (json["total_results"] as? Int) ?? 0)
                    }
                } catch {
                    NSLog("[ShareExtension] Failed to parse response: \(error)")
                    self.showErrorAndDismiss("Failed to parse results")
                }
            }
        }

        task.resume()
    }

    private func showSuccessAndRedirect(resultCount: Int) {
        analyzeNowButton.setTitle("✓ Found \(resultCount) results", for: .normal)

        // Wait briefly to show success message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            // Redirect to main app to show results
            self?.didSelectPost()
        }
    }

    private func showErrorAndDismiss(_ message: String) {
        let alert = UIAlertController(
            title: "Analysis Failed",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: -1))
        })
        present(alert, animated: true)
    }

    // Disable auto-redirect since we're showing custom UI
    override func shouldAutoRedirect() -> Bool {
        return false
    }
}
