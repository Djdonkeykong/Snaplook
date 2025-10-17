//
//  WebViewController.swift
//  Snaplook Share Extension
//
//  Web view for displaying product pages inside the share modal
//

import UIKit
import WebKit

class WebViewController: UIViewController, WKNavigationDelegate {

    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var url: URL
    private weak var shareViewController: RSIShareViewController?

    // Browser UI elements
    private var toolbarContainer: UIView!
    private var backButton: UIButton!
    private var forwardButton: UIButton!
    private var urlBar: UIView!
    private var urlLabel: UILabel!
    private var lockIcon: UIImageView!
    private var refreshButton: UIButton!
    private var shareButton: UIButton!

    // Shimmer loading
    private var shimmerView: UIView!
    private var shimmerGradientLayer: CAGradientLayer!

    init(url: URL, shareViewController: RSIShareViewController) {
        self.url = url
        self.shareViewController = shareViewController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        setupToolbar()
        setupWebView()
        setupShimmer()
        setupNavigationBar()

        // Load the URL
        let request = URLRequest(url: url)
        webView.load(request)

        NSLog("[ShareExtension] WebViewController loading URL: \(url.absoluteString)")
    }

    private func setupNavigationBar() {
        // Add Done button to navigation bar
        let doneButton = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
        navigationItem.rightBarButtonItem = doneButton
    }

    private func setupToolbar() {
        // Container for toolbar
        toolbarContainer = UIView()
        toolbarContainer.backgroundColor = .systemBackground
        toolbarContainer.translatesAutoresizingMaskIntoConstraints = false

        // Back button
        backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .label
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.isEnabled = false

        // Forward button
        forwardButton = UIButton(type: .system)
        forwardButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        forwardButton.tintColor = .label
        forwardButton.addTarget(self, action: #selector(forwardTapped), for: .touchUpInside)
        forwardButton.translatesAutoresizingMaskIntoConstraints = false
        forwardButton.isEnabled = false

        // URL bar background
        urlBar = UIView()
        urlBar.backgroundColor = UIColor.systemGray6
        urlBar.layer.cornerRadius = 10
        urlBar.translatesAutoresizingMaskIntoConstraints = false

        // Lock icon for HTTPS
        lockIcon = UIImageView()
        lockIcon.image = UIImage(systemName: "lock.fill")
        lockIcon.tintColor = .secondaryLabel
        lockIcon.contentMode = .scaleAspectFit
        lockIcon.translatesAutoresizingMaskIntoConstraints = false

        // URL label
        urlLabel = UILabel()
        urlLabel.font = .systemFont(ofSize: 14)
        urlLabel.textColor = .secondaryLabel
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        urlLabel.text = url.host ?? url.absoluteString

        // Refresh button
        refreshButton = UIButton(type: .system)
        refreshButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        refreshButton.tintColor = .label
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        // Share button
        shareButton = UIButton(type: .system)
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.tintColor = .label
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        shareButton.translatesAutoresizingMaskIntoConstraints = false

        // Add to toolbar
        urlBar.addSubview(lockIcon)
        urlBar.addSubview(urlLabel)

        toolbarContainer.addSubview(backButton)
        toolbarContainer.addSubview(forwardButton)
        toolbarContainer.addSubview(urlBar)
        toolbarContainer.addSubview(refreshButton)
        toolbarContainer.addSubview(shareButton)

        view.addSubview(toolbarContainer)

        // Separator line
        let separator = UIView()
        separator.backgroundColor = .systemGray5
        separator.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainer.addSubview(separator)

        NSLayoutConstraint.activate([
            // Toolbar container
            toolbarContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarContainer.heightAnchor.constraint(equalToConstant: 52),

            // Back button
            backButton.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor, constant: 12),
            backButton.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 32),
            backButton.heightAnchor.constraint(equalToConstant: 32),

            // Forward button
            forwardButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 4),
            forwardButton.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor),
            forwardButton.widthAnchor.constraint(equalToConstant: 32),
            forwardButton.heightAnchor.constraint(equalToConstant: 32),

            // Share button (positioned before refresh)
            shareButton.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor, constant: -12),
            shareButton.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor),
            shareButton.widthAnchor.constraint(equalToConstant: 32),
            shareButton.heightAnchor.constraint(equalToConstant: 32),

            // Refresh button
            refreshButton.trailingAnchor.constraint(equalTo: shareButton.leadingAnchor, constant: -4),
            refreshButton.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 32),
            refreshButton.heightAnchor.constraint(equalToConstant: 32),

            // URL bar
            urlBar.leadingAnchor.constraint(equalTo: forwardButton.trailingAnchor, constant: 8),
            urlBar.trailingAnchor.constraint(equalTo: refreshButton.leadingAnchor, constant: -8),
            urlBar.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor),
            urlBar.heightAnchor.constraint(equalToConstant: 36),

            // Lock icon
            lockIcon.leadingAnchor.constraint(equalTo: urlBar.leadingAnchor, constant: 10),
            lockIcon.centerYAnchor.constraint(equalTo: urlBar.centerYAnchor),
            lockIcon.widthAnchor.constraint(equalToConstant: 14),
            lockIcon.heightAnchor.constraint(equalToConstant: 14),

            // URL label
            urlLabel.leadingAnchor.constraint(equalTo: lockIcon.trailingAnchor, constant: 6),
            urlLabel.trailingAnchor.constraint(equalTo: urlBar.trailingAnchor, constant: -10),
            urlLabel.centerYAnchor.constraint(equalTo: urlBar.centerYAnchor),

            // Separator
            separator.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: toolbarContainer.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func setupWebView() {
        // Progress bar for loading indicator
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0)
        progressView.trackTintColor = .clear
        progressView.isHidden = true

        // Configure web view
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.allowsBackForwardNavigationGestures = true
        webView.alpha = 0 // Start hidden for shimmer effect

        view.addSubview(webView)
        view.addSubview(progressView)

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: toolbarContainer.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),

            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Observe loading progress
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
    }

    private func setupShimmer() {
        // Shimmer container
        shimmerView = UIView()
        shimmerView.backgroundColor = .systemBackground
        shimmerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shimmerView)

        NSLayoutConstraint.activate([
            shimmerView.topAnchor.constraint(equalTo: toolbarContainer.bottomAnchor),
            shimmerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            shimmerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            shimmerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Create shimmer boxes to simulate content loading
        let shimmerBoxes = createShimmerBoxes()
        shimmerBoxes.forEach { shimmerView.addSubview($0) }

        // Create shimmer gradient
        shimmerGradientLayer = CAGradientLayer()
        shimmerGradientLayer.colors = [
            UIColor.systemGray6.cgColor,
            UIColor.systemGray5.cgColor,
            UIColor.systemGray6.cgColor
        ]
        shimmerGradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerGradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmerGradientLayer.locations = [0, 0.5, 1]
        shimmerView.layer.addSublayer(shimmerGradientLayer)

        startShimmerAnimation()
    }

    private func createShimmerBoxes() -> [UIView] {
        var boxes: [UIView] = []

        // Create various sized boxes to simulate content
        let boxConfigs: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            // (x, y, width, height)
            (16, 20, 200, 20),      // Title
            (16, 50, 150, 16),      // Subtitle
            (16, 80, view.bounds.width - 32, 200), // Image placeholder
            (16, 300, view.bounds.width - 32, 16), // Line 1
            (16, 330, view.bounds.width - 80, 16), // Line 2
            (16, 360, view.bounds.width - 50, 16), // Line 3
            (16, 400, 120, 40),     // Button
        ]

        for config in boxConfigs {
            let box = UIView()
            box.backgroundColor = .systemGray6
            box.layer.cornerRadius = 8
            box.frame = CGRect(x: config.0, y: config.1, width: config.2, height: config.3)
            boxes.append(box)
        }

        return boxes
    }

    private func startShimmerAnimation() {
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1.0, -0.5, 0.0]
        animation.toValue = [1.0, 1.5, 2.0]
        animation.duration = 1.5
        animation.repeatCount = .infinity
        shimmerGradientLayer?.add(animation, forKey: "shimmer")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        shimmerGradientLayer?.frame = shimmerView.bounds
    }

    private func hideShimmer() {
        UIView.animate(withDuration: 0.3, animations: {
            self.shimmerView.alpha = 0
            self.webView.alpha = 1
        }) { _ in
            self.shimmerView.removeFromSuperview()
            self.shimmerGradientLayer?.removeFromSuperlayer()
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            let progress = Float(webView.estimatedProgress)
            progressView.setProgress(progress, animated: true)

            if progress >= 1.0 {
                UIView.animate(withDuration: 0.3, delay: 0.3, options: .curveEaseOut, animations: {
                    self.progressView.alpha = 0
                }, completion: { _ in
                    self.progressView.isHidden = true
                    self.progressView.alpha = 1
                })
            } else {
                progressView.isHidden = false
            }
        } else if keyPath == "canGoBack" {
            backButton.isEnabled = webView.canGoBack
            backButton.alpha = webView.canGoBack ? 1.0 : 0.3
        } else if keyPath == "canGoForward" {
            forwardButton.isEnabled = webView.canGoForward
            forwardButton.alpha = webView.canGoForward ? 1.0 : 0.3
        } else if keyPath == "url" {
            if let url = webView.url {
                urlLabel.text = url.host ?? url.absoluteString
                lockIcon.isHidden = url.scheme != "https"
            }
        }
    }

    // MARK: - Actions

    @objc private func backTapped() {
        webView.goBack()
    }

    @objc private func forwardTapped() {
        webView.goForward()
    }

    @objc private func refreshTapped() {
        webView.reload()
    }

    @objc private func shareTapped() {
        guard let url = webView.url else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = shareButton
        present(activityVC, animated: true)
    }

    @objc private func doneTapped() {
        NSLog("[ShareExtension] Done button tapped in WebViewController - dismissing web view")

        // Dismiss the modal web view and return to results
        dismiss(animated: true) {
            NSLog("[ShareExtension] WebViewController dismissed - back to results")
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressView.setProgress(0, animated: false)
        progressView.isHidden = false
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationItem.title = webView.title

        // Hide shimmer when content loads
        if shimmerView.superview != nil {
            hideShimmer()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("[ShareExtension] WebView failed to load: \(error.localizedDescription)")
        hideShimmer()
        showError(message: "Failed to load page")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("[ShareExtension] WebView failed provisional navigation: \(error.localizedDescription)")
        hideShimmer()
        showError(message: "Failed to load page")
    }

    private func showError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    deinit {
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
    }
}
