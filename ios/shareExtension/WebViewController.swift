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
    private var urlBar: UIView!
    private var urlLabel: UILabel!
    private var lockIcon: UIImageView!
    private var doneButton: UIButton!

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

        // Load the URL
        let request = URLRequest(url: url)
        webView.load(request)

        NSLog("[ShareExtension] WebViewController loading URL: \(url.absoluteString)")
    }

    private func setupToolbar() {
        // Container for toolbar
        toolbarContainer = UIView()
        toolbarContainer.backgroundColor = .systemBackground
        toolbarContainer.translatesAutoresizingMaskIntoConstraints = false

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

        // Done button
        doneButton = UIButton(type: .system)
        doneButton.setTitle("Done", for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        doneButton.tintColor = .label
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        // Add to toolbar
        urlBar.addSubview(lockIcon)
        urlBar.addSubview(urlLabel)

        toolbarContainer.addSubview(urlBar)
        toolbarContainer.addSubview(doneButton)

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

            // URL bar - extends further right now that arrows are removed
            urlBar.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor, constant: 16),
            urlBar.trailingAnchor.constraint(equalTo: doneButton.leadingAnchor, constant: -12),
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

            // Done button (positioned where share/refresh were)
            doneButton.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor, constant: -16),
            doneButton.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor),
            doneButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),

            // Separator
            separator.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: toolbarContainer.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func setupWebView() {
        // Progress bar for loading indicator (underneath toolbar)
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0)
        progressView.trackTintColor = .systemGray6
        progressView.isHidden = true

        // Configure web view
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.allowsBackForwardNavigationGestures = true

        view.addSubview(progressView)
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            // Progress bar directly under toolbar
            progressView.topAnchor.constraint(equalTo: toolbarContainer.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),

            // Web view below progress bar
            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Observe loading progress and URL
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            let progress = Float(webView.estimatedProgress)
            progressView.setProgress(progress, animated: true)

            if progress >= 1.0 {
                // Fade out progress bar when loading completes
                UIView.animate(withDuration: 0.3, delay: 0.3, options: .curveEaseOut, animations: {
                    self.progressView.alpha = 0
                }, completion: { _ in
                    self.progressView.isHidden = true
                    self.progressView.alpha = 1
                })
            } else {
                progressView.isHidden = false
                progressView.alpha = 1
            }
        } else if keyPath == "url" {
            if let url = webView.url {
                urlLabel.text = url.host ?? url.absoluteString
                lockIcon.isHidden = url.scheme != "https"
            }
        }
    }

    // MARK: - Actions

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
        NSLog("[ShareExtension] WebView finished loading: \(webView.url?.absoluteString ?? "unknown")")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("[ShareExtension] WebView failed to load: \(error.localizedDescription)")
        showError(message: "Failed to load page")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("[ShareExtension] WebView failed provisional navigation: \(error.localizedDescription)")
        showError(message: "Failed to load page")
    }

    private func showError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    deinit {
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
    }
}
