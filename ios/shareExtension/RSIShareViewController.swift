//
//  RSIShareViewController.swift
//  Snaplook Share Extension
//
//  Vendored from receive_sharing_intent (v1.8.1) with logging and
//  main-thread safety so we can debug shares without the full Flutter pod.
//

import UIKit
import Social
import MobileCoreServices
import Photos
import UniformTypeIdentifiers
import AVFoundation

let kSchemePrefix = "ShareMedia"
let kUserDefaultsKey = "ShareKey"
let kUserDefaultsMessageKey = "ShareMessageKey"
let kAppGroupIdKey = "AppGroupId"
let kProcessingStatusKey = "ShareProcessingStatus"
let kProcessingSessionKey = "ShareProcessingSession"
let kScrapingBeeApiKey = "ScrapingBeeApiKey"
let kSerpApiKey = "SerpApiKey"
let kDetectorEndpoint = "DetectorEndpoint"

@inline(__always)
private func shareLog(_ message: String) {
    NSLog("[ShareExtension] %@", message)
}

public class SharedMediaFile: Codable {
    var path: String
    var mimeType: String?
    var thumbnail: String?
    var duration: Double?
    var message: String?
    var type: SharedMediaType

    public init(
        path: String,
        mimeType: String? = nil,
        thumbnail: String? = nil,
        duration: Double? = nil,
        message: String? = nil,
        type: SharedMediaType
    ) {
        self.path = path
        self.mimeType = mimeType
        self.thumbnail = thumbnail
        self.duration = duration
        self.message = message
        self.type = type
    }
}

public enum SharedMediaType: String, Codable, CaseIterable {
    case image
    case video
    case text
    case file
    case url

    public var toUTTypeIdentifier: String {
        if #available(iOS 14.0, *) {
            switch self {
            case .image: return UTType.image.identifier
            case .video: return UTType.movie.identifier
            case .text:  return UTType.text.identifier
            case .file:  return UTType.fileURL.identifier
            case .url:   return UTType.url.identifier
            }
        }
        switch self {
        case .image: return "public.image"
        case .video: return "public.movie"
        case .text:  return "public.text"
        case .file:  return "public.data"
        case .url:   return "public.url"
        }
    }
}

// Detection result model
struct DetectionResultItem: Codable {
    let id: String
    let product_name: String
    let brand: String
    let price: Double
    let image_url: String
    let category: String
    let confidence: Double
    let description: String?
    let purchase_url: String
}

struct DetectionResponse: Codable {
    let success: Bool
    let detected_garment: DetectedGarment?
    let total_results: Int
    let results: [DetectionResultItem]
    let message: String?

    struct DetectedGarment: Codable {
        let label: String
        let score: Double
        let bbox: [Int]
    }
}

@available(swift, introduced: 5.0)
open class RSIShareViewController: SLComposeServiceViewController {
    var hostAppBundleIdentifier = ""
    var appGroupId = ""
    var sharedMedia: [SharedMediaFile] = []
    private var loadingView: UIView?
    private var loadingShownAt: Date?
    private var loadingHideWorkItem: DispatchWorkItem?
    private var currentProcessingSession: String?
    private var didCompleteRequest = false
    private var activityIndicator: UIActivityIndicatorView?
    private var statusLabel: UILabel?
    private var statusPollTimer: Timer?
    private var pendingAttachmentCount = 0
    private var hasQueuedRedirect = false
    private var pendingPostMessage: String?
    private let maxInstagramScrapeAttempts = 2
    private var detectionResults: [DetectionResultItem] = []
    private var resultsTableView: UITableView?
    private var downloadedImageUrl: String?
    private var isShowingDetectionResults = false

    open func shouldAutoRedirect() -> Bool { true }

    open override func isContentValid() -> Bool { true }

    open override func viewDidLoad() {
        super.viewDidLoad()
        loadIds()
        sharedMedia.removeAll()
        shareLog("View did load - cleared sharedMedia array")
        suppressKeyboard()
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            shareLog("Resolved container URL: \(containerURL.path)")
        } else {
            shareLog("ERROR: Failed to resolve container URL for \(appGroupId)")
        }
        loadingHideWorkItem?.cancel()
        setupLoadingUI()
        startStatusPolling()
    }

    open override func didSelectPost() {
        shareLog("didSelectPost invoked")
        pendingPostMessage = contentText
        maybeFinalizeShare()
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        suppressKeyboard()
        guard let content = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = content.attachments else {
            shareLog("No attachments found on extension context")
            return
        }

        pendingAttachmentCount = 0
        hasQueuedRedirect = false
        pendingPostMessage = nil

        if attachments.isEmpty {
            shareLog("No attachments to process")
            maybeFinalizeShare()
            return
        }

        for (index, attachment) in attachments.enumerated() {
            guard let type = SharedMediaType.allCases.first(where: {
                attachment.hasItemConformingToTypeIdentifier($0.toUTTypeIdentifier)
            }) else {
                shareLog("Attachment index \(index) has no supported type")
                continue
            }

            beginAttachmentProcessing()
            shareLog("Loading attachment index \(index) as \(type)")
            attachment.loadItem(
                forTypeIdentifier: type.toUTTypeIdentifier,
                options: nil
            ) { [weak self] data, error in
                guard let self = self else { return }
                if let error = error {
                    shareLog("ERROR: loadItem failed for index \(index) - \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.handleLoadFailure()
                    }
                    return
                }

                DispatchQueue.main.async {
                    self.processLoadedAttachment(
                        data: data,
                        type: type,
                        index: index,
                        content: content
                    )
                }
            }
        }

        maybeFinalizeShare()
    }

    private func performInstagramScrape(
        instagramUrl: String,
        apiKey: String,
        attempt: Int,
        completion: @escaping (Result<[SharedMediaFile], Error>) -> Void
    ) {
        guard attempt <= maxInstagramScrapeAttempts else {
            completion(.failure(makeInstagramError("Exceeded Instagram scrape attempts")))
            return
        }

        guard var components = URLComponents(string: "https://app.scrapingbee.com/api/v1/") else {
            completion(.failure(makeInstagramError("Invalid ScrapingBee URL")))
            return
        }

        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "url", value: instagramUrl),
            URLQueryItem(name: "render_js", value: "true"),
            URLQueryItem(name: "wait", value: "2000")
        ]

        guard let requestURL = components.url else {
            completion(.failure(makeInstagramError("Failed to build ScrapingBee request URL")))
            return
        }

        shareLog("Fetching Instagram HTML via ScrapingBee (attempt \(attempt + 1)) for \(instagramUrl)")

        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 20.0

        let session = URLSession(configuration: .ephemeral)
        let deliver: (Result<[SharedMediaFile], Error>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    completion(result)
                case .failure(let error):
                    if attempt < self.maxInstagramScrapeAttempts {
                        shareLog("WARNING: ScrapingBee attempt \(attempt + 1) failed (\(error.localizedDescription)) - retrying")
                        self.performInstagramScrape(
                            instagramUrl: instagramUrl,
                            apiKey: apiKey,
                            attempt: attempt + 1,
                            completion: completion
                        )
                    } else {
                        shareLog("ERROR: ScrapingBee failed after \(attempt + 1) attempts - \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
            }
        }

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                session.invalidateAndCancel()
                deliver(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                session.invalidateAndCancel()
                deliver(.failure(self.makeInstagramError("Missing HTTP response")))
                return
            }

            guard httpResponse.statusCode == 200 else {
                session.invalidateAndCancel()
                deliver(.failure(self.makeInstagramError("ScrapingBee returned status \(httpResponse.statusCode)", code: httpResponse.statusCode)))
                return
            }

            guard let data = data,
                  let html = String(data: data, encoding: .utf8) else {
                session.invalidateAndCancel()
                deliver(.failure(self.makeInstagramError("Unable to decode ScrapingBee response body")))
                return
            }

            let imageUrls = self.extractInstagramImageUrls(from: html)
            if imageUrls.isEmpty {
                session.invalidateAndCancel()
                deliver(.failure(self.makeInstagramError("No image URLs found in Instagram response")))
                return
            }

            self.downloadInstagramImages(
                imageUrls,
                originalURL: instagramUrl,
                session: session,
                completion: deliver
            )
        }.resume()
    }

    open override func configurationItems() -> [Any]! { [] }

    private func beginAttachmentProcessing() {
        pendingAttachmentCount += 1
    }

    private func completeAttachmentProcessing() {
        pendingAttachmentCount = max(pendingAttachmentCount - 1, 0)
        maybeFinalizeShare()
    }

    private func maybeFinalizeShare() {
        guard pendingAttachmentCount == 0, !hasQueuedRedirect else { return }

        // Don't auto-redirect if we're showing detection results
        if isShowingDetectionResults {
            shareLog("Skipping auto-redirect - showing detection results")
            return
        }

        hasQueuedRedirect = true
        let message = pendingPostMessage
        saveAndRedirect(message: message)
    }

    private func handleLoadFailure() {
        shareLog("Handling load failure for attachment")
        completeAttachmentProcessing()
    }

    private func processLoadedAttachment(
        data: NSSecureCoding?,
        type: SharedMediaType,
        index: Int,
        content: NSExtensionItem
    ) {
        switch type {
        case .text:
            guard let text = data as? String else {
                shareLog("Attachment index \(index) text payload missing")
                completeAttachmentProcessing()
                return
            }
            shareLog("Attachment index \(index) is text")
            handleMedia(
                forLiteral: text,
                type: type,
                index: index,
                content: content
            ) { [weak self] in
                self?.completeAttachmentProcessing()
            }
        case .url:
            if let url = data as? URL {
                shareLog("Attachment index \(index) is URL: \(url)")
                handleMedia(
                    forLiteral: url.absoluteString,
                    type: type,
                    index: index,
                    content: content
                ) { [weak self] in
                    self?.completeAttachmentProcessing()
                }
            } else {
                shareLog("Attachment index \(index) URL payload missing")
                completeAttachmentProcessing()
            }
        default:
            if let url = data as? URL {
                shareLog("Attachment index \(index) is file URL: \(url)")
                handleMedia(
                    forFile: url,
                    type: type,
                    index: index,
                    content: content
                ) { [weak self] in
                    self?.completeAttachmentProcessing()
                }
            } else if let image = data as? UIImage {
                shareLog("Attachment index \(index) is UIImage")
                handleMedia(
                    forUIImage: image,
                    type: type,
                    index: index,
                    content: content
                ) { [weak self] in
                    self?.completeAttachmentProcessing()
                }
            } else {
                shareLog("Attachment index \(index) could not be handled for type \(type)")
                completeAttachmentProcessing()
            }
        }
    }

    private func suppressKeyboard() {
        let isResponder = textView?.isFirstResponder ?? false
        let isEditable = textView?.isEditable ?? false
        shareLog("suppressKeyboard invoked (isFirstResponder: \(isResponder), isEditable: \(isEditable))")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let scheduledResponder = self.textView?.isFirstResponder ?? false
            shareLog("suppressKeyboard applying changes (isFirstResponder: \(scheduledResponder))")
            self.textView?.isEditable = false
            self.textView?.isSelectable = false
            self.textView?.text = ""
            self.placeholder = ""
            self.textView?.resignFirstResponder()
            self.view.endEditing(true)
            self.textView?.inputView = UIView()
            self.textView?.inputAccessoryView = UIView()
            self.textView?.isHidden = true
            let finalResponder = self.textView?.isFirstResponder ?? false
            shareLog("suppressKeyboard completed (isFirstResponder: \(finalResponder))")
        }
    }

    private func loadIds() {
        let shareExtensionAppBundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        shareLog("bundle id: \(shareExtensionAppBundleIdentifier)")

        if let lastDot = shareExtensionAppBundleIdentifier.lastIndex(of: ".") {
            hostAppBundleIdentifier = String(shareExtensionAppBundleIdentifier[..<lastDot])
        }
        let defaultAppGroupId = "group.\(hostAppBundleIdentifier)"
        shareLog("default app group: \(defaultAppGroupId)")

        let customAppGroupId = Bundle.main.object(forInfoDictionaryKey: kAppGroupIdKey) as? String
        shareLog("Info.plist AppGroupId: \(customAppGroupId ?? "nil")")

        if let custom = customAppGroupId,
           !custom.isEmpty,
           custom != "$(CUSTOM_GROUP_ID)" {
            appGroupId = custom
        } else {
            appGroupId = defaultAppGroupId
        }
        shareLog("using app group: \(appGroupId)")
    }

    private func handleMedia(
        forLiteral item: String,
        type: SharedMediaType,
        index: Int,
        content: NSExtensionItem,
        completion: @escaping () -> Void
    ) {
        if type == .url, isInstagramShareCandidate(item) {
            shareLog("Detected Instagram URL share - starting download pipeline")
            updateProcessingStatus("processing")
            downloadInstagramMedia(from: item) { [weak self] result in
                guard let self = self else {
                    completion()
                    return
                }

                switch result {
                case .success(let downloaded):
                    if downloaded.isEmpty {
                        shareLog("Instagram download succeeded but returned no files - falling back to literal URL")
                        self.appendLiteralShare(item: item, type: type)
                    } else {
                        self.sharedMedia.append(contentsOf: downloaded)
                        shareLog("Appended \(downloaded.count) downloaded Instagram file(s) - count now \(self.sharedMedia.count)")
                    }
                case .failure(let error):
                    shareLog("ERROR: Instagram download failed - \(error.localizedDescription)")
                    self.appendLiteralShare(item: item, type: type)
                }

                completion()
            }
            return
        }

        appendLiteralShare(item: item, type: type)
        completion()
    }

    private func handleMedia(
        forUIImage image: UIImage,
        type: SharedMediaType,
        index: Int,
        content: NSExtensionItem,
        completion: @escaping () -> Void
    ) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            shareLog("ERROR: containerURL was nil while handling UIImage")
            completion()
            return
        }
        let tempPath = containerURL.appendingPathComponent("TempImage.png")
        if writeTempFile(image, to: tempPath) {
            let newPathDecoded = tempPath.absoluteString.removingPercentEncoding ?? tempPath.absoluteString
            sharedMedia.append(SharedMediaFile(
                path: newPathDecoded,
                mimeType: type == .image ? "image/png" : nil,
                type: type
            ))
            shareLog("Saved UIImage to \(newPathDecoded) - count now \(sharedMedia.count)")
        } else {
            shareLog("ERROR: Failed to write UIImage for index \(index)")
        }
        completion()
    }

    private func handleMedia(
        forFile url: URL,
        type: SharedMediaType,
        index: Int,
        content: NSExtensionItem,
        completion: @escaping () -> Void
    ) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            shareLog("ERROR: containerURL was nil while handling file URL")
            completion()
            return
        }
        let fileName = getFileName(from: url, type: type)
        let newPath = containerURL.appendingPathComponent(fileName)

        if copyFile(at: url, to: newPath) {
            let newPathDecoded = newPath.absoluteString.removingPercentEncoding ?? newPath.absoluteString
            shareLog("copyFile succeeded to \(newPathDecoded)")
            if type == .video {
                if let videoInfo = getVideoInfo(from: url) {
                    let thumbnailPathDecoded = videoInfo.thumbnail?.removingPercentEncoding
                    sharedMedia.append(SharedMediaFile(
                        path: newPathDecoded,
                        mimeType: url.mimeType(),
                        thumbnail: thumbnailPathDecoded,
                        duration: videoInfo.duration,
                        type: type
                    ))
                    shareLog("Stored video at \(newPathDecoded) - count now \(sharedMedia.count)")
                }
            } else {
                sharedMedia.append(SharedMediaFile(
                    path: newPathDecoded,
                    mimeType: url.mimeType(),
                    type: type
                ))
                shareLog("Stored file at \(newPathDecoded) - count now \(sharedMedia.count)")
            }
        } else {
            shareLog("ERROR: Failed to copy file \(url)")
        }
        completion()
    }

    private func appendLiteralShare(item: String, type: SharedMediaType) {
        let mimeType: String?
        if type == .text {
            mimeType = "text/plain"
        } else if type == .url {
            mimeType = "text/plain"
        } else {
            mimeType = nil
        }

        sharedMedia.append(
            SharedMediaFile(
                path: item,
                mimeType: mimeType,
                message: type == .url ? item : nil,
                type: type
            )
        )
        shareLog("Appended literal item (type \(type)) - count now \(sharedMedia.count)")
    }

    private func isInstagramShareCandidate(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.contains("instagram.com/p/") || trimmed.contains("instagram.com/reel/")
    }

    private func scrapingBeeApiKey() -> String? {
        if let defaults = UserDefaults(suiteName: appGroupId) {
            if let key = defaults.string(forKey: kScrapingBeeApiKey), !key.isEmpty {
                shareLog("Using ScrapingBee key from shared defaults")
                return key
            }
        }

        if let infoKey = Bundle.main.object(forInfoDictionaryKey: "ScrapingBeeApiKey") as? String,
           !infoKey.isEmpty {
            shareLog("Using ScrapingBee key from Info.plist fallback")
            return infoKey
        }

        return nil
    }

    private func updateProcessingStatus(_ status: String) {
        guard !appGroupId.isEmpty,
              let defaults = UserDefaults(suiteName: appGroupId) else { return }
        defaults.set(status, forKey: kProcessingStatusKey)
        defaults.synchronize()
        DispatchQueue.main.async { [weak self] in
            self?.refreshStatusLabel()
        }
    }

    private func makeInstagramError(_ message: String, code: Int = -1) -> NSError {
        NSError(
            domain: "com.snaplook.shareExtension.instagram",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private func downloadInstagramMedia(
        from urlString: String,
        completion: @escaping (Result<[SharedMediaFile], Error>) -> Void
    ) {
        guard let apiKey = scrapingBeeApiKey(), !apiKey.isEmpty else {
            shareLog("ScrapingBee API key missing - falling back to host app download")
            completion(.success([]))
            return
        }

        performInstagramScrape(
            instagramUrl: urlString,
            apiKey: apiKey,
            attempt: 0,
            completion: completion
        )
    }

    // Get detector endpoint from UserDefaults or fallback
    private func detectorEndpoint() -> String? {
        if let defaults = UserDefaults(suiteName: appGroupId),
           let endpoint = defaults.string(forKey: kDetectorEndpoint),
           !endpoint.isEmpty {
            return endpoint
        }
        // Fallback to local/ngrok for development (will be set by Flutter app)
        shareLog("Warning: DetectorEndpoint not found in UserDefaults - run Flutter app first")
        return nil
    }

    // Get SerpAPI key from UserDefaults
    private func serpApiKey() -> String? {
        if let defaults = UserDefaults(suiteName: appGroupId),
           let key = defaults.string(forKey: kSerpApiKey),
           !key.isEmpty {
            return key
        }
        return nil
    }

    // Call detection API with image URL
    private func runDetectionAnalysis(imageUrl: String) {
        guard let endpoint = detectorEndpoint(),
              let serpKey = serpApiKey() else {
            shareLog("Detection endpoint or SerpAPI key not configured - proceeding with normal flow")
            proceedWithNormalFlow()
            return
        }

        shareLog("Starting detection analysis for: \(imageUrl)")
        updateStatusLabel("Analyzing your photo...")

        let requestBody: [String: Any] = [
            "image_url": imageUrl,
            "serp_api_key": serpKey,
            "max_results_per_garment": 10
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody),
              let url = URL(string: endpoint) else {
            shareLog("Failed to prepare detection request")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30.0

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                shareLog("Detection API error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.proceedWithNormalFlow()
                }
                return
            }

            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                shareLog("Detection API failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                DispatchQueue.main.async {
                    self.proceedWithNormalFlow()
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let detectionResponse = try decoder.decode(DetectionResponse.self, from: data)

                if detectionResponse.success {
                    shareLog("Detection successful: \(detectionResponse.total_results) results")
                    DispatchQueue.main.async {
                        self.detectionResults = detectionResponse.results
                        self.isShowingDetectionResults = true
                        self.showDetectionResults()
                    }
                } else {
                    shareLog("Detection failed: \(detectionResponse.message ?? "Unknown error")")
                    // If detection fails, allow normal redirect
                    DispatchQueue.main.async {
                        self.proceedWithNormalFlow()
                    }
                }
            } catch {
                shareLog("Failed to parse detection response: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.proceedWithNormalFlow()
                }
            }
        }

        task.resume()
    }

    // Upload image to ImgBB and trigger detection
    private func uploadAndDetect(imageData: Data) {
        shareLog("Uploading image to ImgBB for detection...")
        updateStatusLabel("Uploading photo...")

        let base64Image = imageData.base64EncodedString()
        let params = [
            "key": "d7e1d857e4498c2e28acaa8d943ccea8",
            "image": base64Image
        ]

        guard let url = URL(string: "https://api.imgbb.com/1/upload") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        var components = URLComponents()
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = components.query?.data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                shareLog("ImgBB upload error: \(error.localizedDescription)")
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataDict = json["data"] as? [String: Any],
                  let imageUrl = dataDict["url"] as? String else {
                shareLog("Failed to parse ImgBB response")
                return
            }

            shareLog("ImgBB upload successful: \(imageUrl)")
            self.downloadedImageUrl = imageUrl

            // Trigger detection
            self.runDetectionAnalysis(imageUrl: imageUrl)
        }

        task.resume()
    }

    // Update status label helper
    private func updateStatusLabel(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel?.text = text
        }
    }

    // Show detection results in table view
    private func showDetectionResults() {
        guard !detectionResults.isEmpty else { return }

        shareLog("Showing \(detectionResults.count) detection results")

        // Hide loading indicator
        activityIndicator?.stopAnimating()
        activityIndicator?.isHidden = true
        statusLabel?.isHidden = true

        // Create table view if not exists
        if resultsTableView == nil {
            let tableView = UITableView(frame: view.bounds, style: .plain)
            tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            tableView.delegate = self
            tableView.dataSource = self
            tableView.register(ResultCell.self, forCellReuseIdentifier: "ResultCell")
            tableView.rowHeight = UITableView.automaticDimension
            tableView.estimatedRowHeight = 100
            tableView.backgroundColor = .systemBackground
            loadingView?.addSubview(tableView)
            resultsTableView = tableView
        }

        resultsTableView?.reloadData()
    }

    // Proceed with normal flow (save and redirect to app)
    private func proceedWithNormalFlow() {
        guard !hasQueuedRedirect else { return }
        shareLog("Proceeding with normal flow (no detection results)")
        isShowingDetectionResults = false
        hasQueuedRedirect = true
        saveAndRedirect()
    }

    private func extractInstagramImageUrls(from html: String) -> [String] {
        var priorityResults: [String] = []
        var results: [String] = []
        let cacheKeyPattern = "\"src\":\"(https:\\\\/\\\\/scontent[^\"]+?ig_cache_key[^\"]*)\""
        if let regex = try? NSRegularExpression(pattern: cacheKeyPattern, options: []) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, options: [], range: nsrange) { match, _, _ in
                guard let match = match,
                      match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else { return }
                let candidate = sanitizeInstagramURLString(String(html[range]))
                if !candidate.isEmpty && !priorityResults.contains(candidate) {
                    priorityResults.append(candidate)
                }
            }
        }

        let pattern = "\"display_url\"\\s*:\\s*\"([^\"]+)\""

        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, options: [], range: nsrange) { match, _, _ in
                guard let match = match,
                      match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else { return }

                var candidate = String(html[range])
                candidate = sanitizeInstagramURLString(candidate)
                if candidate.contains("150x150") || candidate.contains("profile") {
                    return
                }
                if !results.contains(candidate) {
                    results.append(candidate)
                }
            }
        }

        let imgPattern = "<img[^>]+src=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: imgPattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, options: [], range: nsrange) { match, _, _ in
                guard let match = match,
                      match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else { return }
                let candidate = sanitizeInstagramURLString(String(html[range]))
                if candidate.contains("ig_cache_key") && !priorityResults.contains(candidate) {
                    priorityResults.append(candidate)
                } else if !candidate.contains("ig_cache_key"),
                          !results.contains(candidate) {
                    results.append(candidate)
                }
            }
        }

        if !priorityResults.isEmpty {
            return priorityResults
        }

        if !results.isEmpty {
            return results
        }

        let ogPattern = "<meta property=\"og:image\" content=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: ogPattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            if let match = regex.firstMatch(in: html, options: [], range: nsrange),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: html) {
                let candidate = sanitizeInstagramURLString(String(html[range]))
                if !candidate.isEmpty {
                    results.append(candidate)
                }
            }
        }

        return results
    }

    private func sanitizeInstagramURLString(_ value: String) -> String {
        var sanitized = value
        sanitized = sanitized.replacingOccurrences(of: "\\u0026", with: "&")
        sanitized = sanitized.replacingOccurrences(of: "\\/", with: "/")
        sanitized = sanitized.replacingOccurrences(of: "&amp;", with: "&")
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.contains("ig_cache_key") {
            return sanitized
        }
        return normalizeInstagramCdnUrl(sanitized)
    }

    private func normalizeInstagramCdnUrl(_ urlString: String) -> String {
        guard var components = URLComponents(string: urlString) else {
            return urlString
        }

        if var queryItems = components.percentEncodedQueryItems {
            for index in 0..<queryItems.count {
                if queryItems[index].name == "stp",
                   let value = queryItems[index].value,
                   value.contains("c") || value.contains("s640x640") {
                    queryItems[index].value = value
                        .replacingOccurrences(of: "c288.0.864.864a_", with: "")
                        .replacingOccurrences(of: "s640x640_", with: "")
                }
            }
            components.percentEncodedQueryItems = queryItems
        }

        let path = components.percentEncodedPath
        if let regex = try? NSRegularExpression(pattern: "_s\\d+x\\d+", options: []) {
            let range = NSRange(location: 0, length: path.count)
            if regex.firstMatch(in: path, options: [], range: range) != nil {
                let mutablePath = NSMutableString(string: path)
                regex.replaceMatches(in: mutablePath, options: [], range: range, withTemplate: "")
                components.percentEncodedPath = mutablePath as String
            }
        }

        return components.string ?? urlString
    }

    private func downloadInstagramImages(
        _ urls: [String],
        originalURL: String,
        session: URLSession,
        completion: @escaping (Result<[SharedMediaFile], Error>) -> Void
    ) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            completion(.failure(makeInstagramError("Unable to resolve shared container URL")))
            return
        }

        var uniqueUrls: [String] = []
        for url in urls {
            let sanitized = sanitizeInstagramURLString(url)
            if !sanitized.isEmpty && !uniqueUrls.contains(sanitized) {
                uniqueUrls.append(sanitized)
                shareLog("Queueing Instagram image candidate: \(sanitized)")
            }
        }

        guard !uniqueUrls.isEmpty else {
            completion(.failure(makeInstagramError("No valid Instagram image URLs after sanitization")))
            return
        }

        func attempt(index: Int) {
            if index >= uniqueUrls.count {
                session.invalidateAndCancel()
                completion(.failure(makeInstagramError("All Instagram image downloads failed")))
                return
            }

            let targetUrl = uniqueUrls[index]
            shareLog("Attempting Instagram image download \(index + 1)/\(uniqueUrls.count): \(targetUrl)")

            downloadSingleImage(
                urlString: targetUrl,
                originalURL: originalURL,
                containerURL: containerURL,
                session: session,
                index: index
            ) { result in
                switch result {
                case .success(let file):
                    session.finishTasksAndInvalidate()
                    if let file = file {
                        completion(.success([file]))
                    } else {
                        completion(.success([]))
                    }
                case .failure(let error):
                    shareLog("WARNING: Instagram download candidate failed (\(error.localizedDescription)) - trying next")
                    attempt(index: index + 1)
                }
            }
        }

        attempt(index: 0)
    }

    private func downloadSingleImage(
        urlString: String,
        originalURL: String,
        containerURL: URL,
        session: URLSession,
        index: Int,
        completion: @escaping (Result<SharedMediaFile?, Error>) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(.failure(makeInstagramError("Invalid image URL: \(urlString)")))
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20.0
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.instagram.com/", forHTTPHeaderField: "Referer")

        shareLog("Downloading Instagram CDN image: \(urlString)")
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(self.makeInstagramError("Image download failed with status \(status)", code: status)))
                return
            }

            guard let data = data else {
                completion(.failure(self.makeInstagramError("Image download returned no data")))
                return
            }

            let timestamp = Int(Date().timeIntervalSince1970 * 1000)
            let fileName = "instagram_image_\(timestamp)_\(index).jpg"
            let fileURL = containerURL.appendingPathComponent(fileName)

            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
                try data.write(to: fileURL, options: .atomic)
                shareLog("Saved Instagram image to shared container: \(fileURL.path)")

                let sharedFile = SharedMediaFile(
                    path: fileURL.absoluteString,
                    mimeType: "image/jpeg",
                    message: originalURL,
                    type: .image
                )

                // Upload to ImgBB and trigger detection (async - don't complete yet)
                self.uploadAndDetect(imageData: data)

                // Return success but don't trigger redirect yet
                // The redirect will happen when user selects a result OR if detection fails
                completion(.success(sharedFile))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func saveAndRedirect(message: String? = nil) {
        hasQueuedRedirect = true
        let userDefaults = UserDefaults(suiteName: appGroupId)
        userDefaults?.set(toData(data: sharedMedia), forKey: kUserDefaultsKey)
        let resolvedMessage = (message?.isEmpty ?? true) ? nil : message
        userDefaults?.set(resolvedMessage, forKey: kUserDefaultsMessageKey)
        let sessionId = UUID().uuidString
        currentProcessingSession = sessionId
        userDefaults?.set("pending", forKey: kProcessingStatusKey)
        userDefaults?.set(sessionId, forKey: kProcessingSessionKey)
        userDefaults?.synchronize()
        shareLog("Saved \(sharedMedia.count) item(s) to UserDefaults - redirecting (session: \(sessionId))")
        pendingPostMessage = nil
        redirectToHostApp(sessionId: sessionId)
    }

    private func redirectToHostApp(sessionId: String) {
        loadIds()
        guard let redirectURL = URL(string: "\(kSchemePrefix)-\(hostAppBundleIdentifier):share") else {
            shareLog("ERROR: Failed to build redirect URL")
            dismissWithError()
            return
        }

        let minimumDuration: TimeInterval = 0.5
        let elapsed = loadingShownAt.map { Date().timeIntervalSince($0) } ?? 0
        let delay = max(0, minimumDuration - elapsed)
        shareLog("Redirect scheduled in \(delay) seconds (elapsed: \(elapsed))")

        loadingHideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.loadingHideWorkItem = nil
            self.performRedirect(to: redirectURL)
            self.finishExtensionRequest()
        }
        loadingHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }


    private func performRedirect(to url: URL) {
        shareLog("Redirecting to host app with URL: \(url.absoluteString)")
        var responder: UIResponder? = self
        if #available(iOS 18.0, *) {
            while let current = responder {
                if let application = current as? UIApplication {
                    application.open(url, options: [:], completionHandler: nil)
                    break
                }
                responder = current.next
            }
        } else {
            let selectorOpenURL = sel_registerName("openURL:")
            while let current = responder {
                if current.responds(to: selectorOpenURL) {
                    _ = current.perform(selectorOpenURL, with: url)
                    break
                }
                responder = current.next
            }
        }
    }

    private func finishExtensionRequest() {
        guard !didCompleteRequest else { return }
        didCompleteRequest = true
        DispatchQueue.main.async {
            self.currentProcessingSession = nil
            if let defaults = UserDefaults(suiteName: self.appGroupId) {
                defaults.removeObject(forKey: kProcessingStatusKey)
                defaults.removeObject(forKey: kProcessingSessionKey)
                defaults.synchronize()
            }
            self.hideLoadingUI()
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            shareLog("Completed extension request")
        }
    }

    private func dismissWithError() {
        shareLog("ERROR: dismissWithError called")
        DispatchQueue.main.async {
            self.hideLoadingUI()
            let alert = UIAlertController(title: "Error", message: "Error loading data", preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .cancel) { _ in
                self.dismiss(animated: true, completion: nil)
            }
            alert.addAction(action)
            self.present(alert, animated: true, completion: nil)
            self.didCompleteRequest = true
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    private func getFileName(from url: URL, type: SharedMediaType) -> String {
        var name = url.lastPathComponent
        if name.isEmpty {
            switch type {
            case .image: name = UUID().uuidString + ".png"
            case .video: name = UUID().uuidString + ".mp4"
            case .text:  name = UUID().uuidString + ".txt"
            default:     name = UUID().uuidString
            }
        }
        return name
    }

    private func writeTempFile(_ image: UIImage, to dstURL: URL) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: dstURL.path) {
                try FileManager.default.removeItem(at: dstURL)
            }
            let pngData = image.pngData()
            try pngData?.write(to: dstURL)
            shareLog("writeTempFile succeeded at \(dstURL.path)")
            return true
        } catch {
            shareLog("ERROR: Cannot write temp file - \(error.localizedDescription)")
            return false
        }
    }

    private func copyFile(at srcURL: URL, to dstURL: URL) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: dstURL.path) {
                try FileManager.default.removeItem(at: dstURL)
            }
            try FileManager.default.copyItem(at: srcURL, to: dstURL)
            return true
        } catch {
            shareLog("ERROR: Cannot copy item from \(srcURL) to \(dstURL.path): \(error.localizedDescription)")
            return false
        }
    }

    private func getVideoInfo(from url: URL) -> (thumbnail: String?, duration: Double)? {
        let asset = AVAsset(url: url)
        let duration = (CMTimeGetSeconds(asset.duration) * 1000).rounded()
        let thumbnailPath = getThumbnailPath(for: url)

        if FileManager.default.fileExists(atPath: thumbnailPath.path) {
            return (thumbnail: thumbnailPath.absoluteString, duration: duration)
        }

        var saved = false
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        assetImgGenerate.maximumSize = CGSize(width: 360, height: 360)
        do {
            let img = try assetImgGenerate.copyCGImage(at: CMTimeMakeWithSeconds(0, preferredTimescale: 1), actualTime: nil)
            try UIImage(cgImage: img).pngData()?.write(to: thumbnailPath)
            saved = true
        } catch {
            shareLog("ERROR: Failed to generate video thumbnail - \(error.localizedDescription)")
            saved = false
        }

        return saved ? (thumbnail: thumbnailPath.absoluteString, duration: duration) : nil
    }

    private func getThumbnailPath(for url: URL) -> URL {
        let fileName = Data(url.lastPathComponent.utf8).base64EncodedString().replacingOccurrences(of: "==", with: "")
        return FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)!
            .appendingPathComponent("\(fileName).jpg")
    }

    private func toData(data: [SharedMediaFile]) -> Data {
        (try? JSONEncoder().encode(data)) ?? Data()
    }

    private func setupLoadingUI() {
        let overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor.systemBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let activity = UIActivityIndicatorView(style: .large)
        activity.startAnimating()
        activityIndicator = activity
        stack.addArrangedSubview(activity)

        let status = UILabel()
        status.text = "Fetching your photo..."
        status.font = UIFont.preferredFont(forTextStyle: .body)
        status.textAlignment = .center
        status.textColor = UIColor.secondaryLabel
        status.numberOfLines = 2
        stack.addArrangedSubview(status)
        statusLabel = status

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cancelButton.addTarget(self, action: #selector(cancelImportTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        overlay.addSubview(stack)
        overlay.addSubview(cancelButton)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            cancelButton.topAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.topAnchor, constant: 12),
            cancelButton.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -16)
        ])

        view.addSubview(overlay)
        loadingView = overlay
        loadingShownAt = Date()
    }

    private func startStatusPolling() {
        guard !appGroupId.isEmpty else { return }
        stopStatusPolling()

        statusPollTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.refreshStatusLabel()
        }
        statusPollTimer?.tolerance = 0.1
        if let timer = statusPollTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        refreshStatusLabel()
    }

    private func stopStatusPolling() {
        statusPollTimer?.invalidate()
        statusPollTimer = nil
    }

    private func refreshStatusLabel() {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel?.text = "Fetching your photo..."
        }
    }

    private func hideLoadingUI() {
        loadingHideWorkItem?.cancel()
        loadingHideWorkItem = nil
        loadingView?.removeFromSuperview()
        loadingView = nil
        activityIndicator?.stopAnimating()
        activityIndicator = nil
        stopStatusPolling()
        statusLabel = nil
    }

    @objc private func cancelImportTapped() {
        shareLog("Cancel tapped")
        loadingHideWorkItem?.cancel()
        loadingHideWorkItem = nil
        clearSharedData()
        hideLoadingUI()
        let error = NSError(
            domain: "com.snaplook.shareExtension",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "User cancelled import"]
        )
        didCompleteRequest = true
        extensionContext?.cancelRequest(withError: error)
    }

    private func clearSharedData() {
        sharedMedia.removeAll()
        if let defaults = UserDefaults(suiteName: appGroupId) {
            defaults.removeObject(forKey: kUserDefaultsKey)
            defaults.removeObject(forKey: kUserDefaultsMessageKey)
            defaults.removeObject(forKey: kProcessingStatusKey)
            defaults.removeObject(forKey: kProcessingSessionKey)
            defaults.synchronize()
        }
    }
}

// MARK: - Table View Delegate & DataSource
extension RSIShareViewController: UITableViewDelegate, UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return detectionResults.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ResultCell", for: indexPath) as! ResultCell
        let result = detectionResults[indexPath.row]
        cell.configure(with: result)
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedResult = detectionResults[indexPath.row]
        shareLog("User selected result: \(selectedResult.product_name)")

        // Save selected result and redirect to app
        saveSelectedResultAndRedirect(selectedResult)
    }

    private func saveSelectedResultAndRedirect(_ result: DetectionResultItem) {
        // Save the selected result to UserDefaults to be picked up by the main app
        if let defaults = UserDefaults(suiteName: appGroupId) {
            let resultData: [String: Any] = [
                "product_name": result.product_name,
                "brand": result.brand,
                "price": result.price,
                "image_url": result.image_url,
                "purchase_url": result.purchase_url,
                "category": result.category
            ]

            if let jsonData = try? JSONSerialization.data(withJSONObject: resultData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                defaults.set(jsonString, forKey: "SelectedDetectionResult")
                defaults.synchronize()
            }
        }

        // Redirect to app
        loadIds()
        guard let redirectURL = URL(string: "\(kSchemePrefix)-\(hostAppBundleIdentifier):detection") else {
            shareLog("ERROR: Failed to build redirect URL")
            return
        }

        shareLog("Redirecting to app with selected result")
        performRedirect(to: redirectURL)
        finishExtensionRequest()
    }
}

// MARK: - Result Cell
class ResultCell: UITableViewCell {
    private let productImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let brandLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(productImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(brandLabel)
        contentView.addSubview(priceLabel)

        NSLayoutConstraint.activate([
            productImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            productImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            productImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            productImageView.widthAnchor.constraint(equalToConstant: 80),
            productImageView.heightAnchor.constraint(equalToConstant: 80),

            titleLabel.leadingAnchor.constraint(equalTo: productImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),

            brandLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            brandLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            brandLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            priceLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            priceLabel.topAnchor.constraint(equalTo: brandLabel.bottomAnchor, constant: 4)
        ])
    }

    func configure(with result: DetectionResultItem) {
        titleLabel.text = result.product_name
        brandLabel.text = result.brand

        if result.price > 0 {
            priceLabel.text = String(format: "$%.2f", result.price)
        } else {
            priceLabel.text = "View Product"
        }

        // Load image asynchronously
        productImageView.image = nil
        if let url = URL(string: result.image_url) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.productImageView.image = image
                    }
                }
            }.resume()
        }
    }
}

extension URL {
    func mimeType() -> String {
        if #available(iOS 14.0, *) {
            if let mimeType = UTType(filenameExtension: self.pathExtension)?.preferredMIMEType {
                return mimeType
            }
        } else {
            if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, self.pathExtension as NSString, nil)?.takeRetainedValue() {
                if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                    return mimetype as String
                }
            }
        }
        return "application/octet-stream"
    }
}
