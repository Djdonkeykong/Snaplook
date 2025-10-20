import UIKit

class ShareViewController: RSIShareViewController {

    // MARK: - UI Components
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let analyzeInAppButton = UIButton(type: .system)
    private let analyzeNowButton = UIButton(type: .system)
    private let disclaimerLabel = UILabel()
    private var awaitingImmediateAnalysis = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        // Call super to initialize base class (needed for sharedMedia, appGroupId, etc.)
        super.viewDidLoad()

        // Immediately show our custom UI on top of any base class UI
        setupCustomUI()
        hideLoadingOverlay()
        showCustomUIElements()

        NSLog("[ShareExtension] Custom UI initialized - showing choice screen")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Ensure our UI is visible and on top
        showCustomUIElements()
        view.bringSubviewToFront(containerView)

        NSLog("[ShareExtension] Custom choice screen visible")
    }

    // MARK: - UI Setup
    private func setupCustomUI() {
        view.backgroundColor = .systemBackground

        containerView.tag = 9999
        containerView.backgroundColor = .clear
        containerView.layer.cornerRadius = 0
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        titleLabel.text = "How would you like to analyze this image?"
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = UIColor(red: 28/255, green: 28/255, blue: 37/255, alpha: 1.0)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        configureButton(
            analyzeInAppButton,
            title: "Analyze in App",
            isPrimary: false,
            action: #selector(analyzeInAppTapped)
        )
        containerView.addSubview(analyzeInAppButton)

        configureButton(
            analyzeNowButton,
            title: "Analyze Now",
            isPrimary: true,
            action: #selector(analyzeNowTapped)
        )
        containerView.addSubview(analyzeNowButton)

        disclaimerLabel.text = "Tip: Analyzing in-app lets you crop the image to use fewer search credits."
        disclaimerLabel.numberOfLines = 0
        disclaimerLabel.textAlignment = .center
        disclaimerLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        disclaimerLabel.textColor = UIColor(red: 107/255, green: 114/255, blue: 128/255, alpha: 1.0)
        disclaimerLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(disclaimerLabel)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            containerView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 0),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: 0),

            analyzeInAppButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            analyzeInAppButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            analyzeInAppButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            analyzeInAppButton.heightAnchor.constraint(equalToConstant: 52),

            analyzeNowButton.topAnchor.constraint(equalTo: analyzeInAppButton.bottomAnchor, constant: 12),
            analyzeNowButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            analyzeNowButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            analyzeNowButton.heightAnchor.constraint(equalToConstant: 52),

            disclaimerLabel.topAnchor.constraint(equalTo: analyzeNowButton.bottomAnchor, constant: 16),
            disclaimerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            disclaimerLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            disclaimerLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])

        showCustomUIElements()
    }

    private func showCustomUIElements() {
        [containerView, titleLabel, analyzeInAppButton, analyzeNowButton, disclaimerLabel].forEach { element in
            element.isHidden = false
            element.alpha = 1.0
        }
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
        analyzeInAppButton.isEnabled = false
        analyzeNowButton.isEnabled = false
        // Mark as user-initiated so didSelectPost won't be blocked
        isUserInitiated = true
        processAttachmentsIfNeeded()
        // Trigger the standard redirect flow - user will crop in Snaplook
        didSelectPost()
    }

    @objc private func analyzeNowTapped() {
        NSLog("[ShareExtension] User selected: Analyze Now")

        // Disable button and show loading state
        analyzeNowButton.isEnabled = false
        analyzeNowButton.setTitle("Analyzing...", for: .normal)
        analyzeInAppButton.isEnabled = false

        awaitingImmediateAnalysis = true
        processAttachmentsIfNeeded()
        if !sharedMedia.isEmpty {
            attachmentProcessingDidFinish()
        }
    }

    override func attachmentProcessingDidFinish() {
        super.attachmentProcessingDidFinish()
        if awaitingImmediateAnalysis {
            awaitingImmediateAnalysis = false
            performImmediateAnalysis()
        }
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
        analyzeNowButton.setTitle("Found \(resultCount) results", for: .normal)

        // Wait briefly to show success message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            // Mark as user-initiated so didSelectPost won't be blocked
            self.isUserInitiated = true
            // Redirect to main app to show results
            self.didSelectPost()
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

    override func shouldUseDefaultLoadingUI() -> Bool {
        return false
    }

    override func shouldAutoStartDetection() -> Bool {
        return false
    }

    override func shouldAutoProcessAttachments() -> Bool {
        return false
    }

    override func shouldAutoFinalizeShare() -> Bool {
        return isUserInitiated
    }

    // Disable auto-redirect since we're showing custom UI
    override func shouldAutoRedirect() -> Bool {
        return false
    }

    // Override to prevent base class from auto-posting
    override func didSelectPost() {
        // Only allow posting when explicitly called by our button handlers
        // Check if this was called by us (not by base class)
        if isUserInitiated {
            super.didSelectPost()
            isUserInitiated = false
        } else {
            NSLog("[ShareExtension] Blocked auto-post from base class")
        }
    }

    private var isUserInitiated = false
}
