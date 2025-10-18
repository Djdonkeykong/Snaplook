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
import WebKit

let kSchemePrefix = "ShareMedia"
let kUserDefaultsKey = "ShareKey"
let kUserDefaultsMessageKey = "ShareMessageKey"
let kAppGroupIdKey = "AppGroupId"
let kProcessingStatusKey = "ShareProcessingStatus"
let kProcessingSessionKey = "ShareProcessingSession"
let kScrapingBeeApiKey = "ScrapingBeeApiKey"
let kSerpApiKey = "SerpApiKey"
let kDetectorEndpoint = "DetectorEndpoint"
let kShareExtensionLogKey = "ShareExtensionLogEntries"

@inline(__always)
private func shareLog(_ message: String) {
    NSLog("[ShareExtension] %@", message)
    ShareLogger.shared.append(message)
}

final class ShareLogger {
    static let shared = ShareLogger()

    private let queue = DispatchQueue(label: "com.snaplook.shareExtension.logger")
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private var defaults: UserDefaults?
    private let maxEntries = 200

    func configure(appGroupId: String) {
        queue.async {
            self.defaults = UserDefaults(suiteName: appGroupId)
        }
    }

    func append(_ message: String) {
        queue.async {
            guard let defaults = self.defaults else { return }
            let timestamp = self.isoFormatter.string(from: Date())
            var entries = defaults.stringArray(forKey: kShareExtensionLogKey) ?? []
            entries.append("[\(timestamp)] \(message)")
            if entries.count > self.maxEntries {
                entries.removeFirst(entries.count - self.maxEntries)
            }
            defaults.set(entries, forKey: kShareExtensionLogKey)
        }
    }

    func clear() {
        queue.async { [weak self] in
            guard let defaults = self?.defaults else { return }
            defaults.removeObject(forKey: kShareExtensionLogKey)
        }
    }
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
    let brand: String?
    private let priceNumeric: Double?
    private let priceText: String?
    let image_url: String
    let category: String
    let confidence: Double?
    let description: String?
    let purchase_url: String?

    enum CodingKeys: String, CodingKey {
        case id
        case product_name
        case brand
        case price
        case image_url
        case category
        case confidence
        case description
        case purchase_url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        let rawName = (try? container.decode(String.self, forKey: .product_name)) ?? ""
        product_name = rawName.isEmpty ? "Untitled" : rawName

        let rawBrand = try? container.decodeIfPresent(String.self, forKey: .brand)
        if let trimmedBrand = rawBrand?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedBrand.isEmpty {
            brand = trimmedBrand
        } else {
            brand = nil
        }

        var numeric: Double? = nil
        var textValue: String? = nil
        if let doubleValue = try? container.decode(Double.self, forKey: .price) {
            numeric = doubleValue
        } else if let intValue = try? container.decode(Int.self, forKey: .price) {
            numeric = Double(intValue)
        } else if let stringValue = try? container.decode(String.self, forKey: .price) {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                textValue = trimmed
            }
            let digits = trimmed.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
                .replacingOccurrences(of: ",", with: "")
            if let parsed = Double(digits), parsed.isFinite {
                numeric = parsed
            }
        }
        priceNumeric = numeric
        priceText = textValue

        image_url = (try? container.decode(String.self, forKey: .image_url)) ?? ""
        let rawCategory = (try? container.decode(String.self, forKey: .category)) ?? ""
        category = rawCategory.isEmpty ? "Uncategorized" : rawCategory
        confidence = try? container.decodeIfPresent(Double.self, forKey: .confidence)
        description = try? container.decodeIfPresent(String.self, forKey: .description)
        purchase_url = try? container.decodeIfPresent(String.self, forKey: .purchase_url)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(product_name, forKey: .product_name)
        if let brand = brand {
            try container.encode(brand, forKey: .brand)
        } else {
            try container.encodeNil(forKey: .brand)
        }
        if let text = priceText, !text.isEmpty {
            try container.encode(text, forKey: .price)
        } else if let numeric = priceNumeric {
            try container.encode(numeric, forKey: .price)
        } else {
            try container.encodeNil(forKey: .price)
        }
        try container.encode(image_url, forKey: .image_url)
        try container.encode(category, forKey: .category)
        if let confidence = confidence {
            try container.encode(confidence, forKey: .confidence)
        } else {
            try container.encodeNil(forKey: .confidence)
        }
        if let description = description {
            try container.encode(description, forKey: .description)
        } else {
            try container.encodeNil(forKey: .description)
        }
        if let purchase_url = purchase_url {
            try container.encode(purchase_url, forKey: .purchase_url)
        } else {
            try container.encodeNil(forKey: .purchase_url)
        }
    }

    var priceValue: Double? { priceNumeric }

    var priceDisplay: String? {
        if let text = priceText, !text.isEmpty {
            return text
        }
        if let numeric = priceNumeric, numeric > 0 {
            return String(format: "$%.2f", numeric)
        }
        return nil
    }
}

struct DetectionResponse: Codable {
    let success: Bool
    let detected_garment: DetectedGarment?
    let total_results: Int
    let results: [DetectionResultItem]
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case detected_garment
        case total_results
        case results
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? container.decode(Bool.self, forKey: .success)) ?? false
        detected_garment = try? container.decodeIfPresent(DetectedGarment.self, forKey: .detected_garment)
        if let total = try? container.decode(Int.self, forKey: .total_results) {
            total_results = total
        } else if let decodedResults = try? container.decode([DetectionResultItem].self, forKey: .results) {
            total_results = decodedResults.count
        } else {
            total_results = 0
        }
        results = (try? container.decode([DetectionResultItem].self, forKey: .results)) ?? []
        message = try? container.decodeIfPresent(String.self, forKey: .message)
    }

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
    private var isPhotosSourceApp = false
    private let photoImportStatusMessage = "Importing your photo..."
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
    private var filteredResults: [DetectionResultItem] = []
    private var resultsTableView: UITableView?
    private var downloadedImageUrl: String?
    private var isShowingDetectionResults = false
    private var shouldAttemptDetection = false
    private var pendingSharedFile: SharedMediaFile?
    private var pendingImageData: Data?
    private var pendingImageUrl: String?
    private var selectedCategory: String = "All"
    private var categoryFilterView: UIView?
    private var hasProcessedAttachments = false
    private var progressView: UIProgressView?
    private var progressTimer: Timer?
    private var currentProgress: Float = 0.0
    private var targetProgress: Float = 0.0
    private var statusRotationTimer: Timer?
    private var currentStatusMessages: [String] = []
    private var currentStatusIndex: Int = 0
    private var backgroundActivity: NSObjectProtocol?
    private var hasPresentedDetectionFailureAlert = false
    private var headerContainerView: UIView?
    private var headerLogoImageView: UIImageView?
    private var cancelButtonView: UIButton?

    open func shouldAutoRedirect() -> Bool { true }

    open override func isContentValid() -> Bool { true }

    private func hideDefaultUI() {
        // Hide and disable the default text view
        textView?.isHidden = true
        textView?.isEditable = false
        textView?.isSelectable = false
        textView?.alpha = 0
        textView?.text = ""
        placeholder = ""

        // Ensure content view is not visible
        if let contentView = textView?.superview {
            contentView.isHidden = true
            contentView.alpha = 0
        }

        // Hide any other default subviews
        view.subviews.forEach { subview in
            if subview !== loadingView && subview.tag != 9999 {
                subview.isHidden = true
                subview.alpha = 0
            }
        }
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        // Immediately hide and disable all default SLComposeServiceViewController UI
        hideDefaultUI()
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = nil

        loadIds()
        ShareLogger.shared.configure(appGroupId: appGroupId)
        sharedMedia.removeAll()
        shareLog("View did load - cleared sharedMedia array")
        if let sourceBundle = readSourceApplicationBundleIdentifier() {
            shareLog("Source application bundle: \(sourceBundle)")
            let photosBundles: Set<String> = [
                "com.apple.mobileslideshow",
                "com.apple.Photos"
            ]
            if photosBundles.contains(sourceBundle) {
                isPhotosSourceApp = true
                shareLog("Detected Photos source app - enforcing minimum 2s redirect delay")
            }
        } else {
            shareLog("Source application bundle: nil")
        }
        suppressKeyboard()
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            shareLog("Resolved container URL: \(containerURL.path)")
        } else {
            shareLog("ERROR: Failed to resolve container URL for \(appGroupId)")
        }
        loadingHideWorkItem?.cancel()
        setupLoadingUI()
        startStatusPolling()
        enforcePhotosStatusIfNeeded()
    }

    private func readSourceApplicationBundleIdentifier() -> String? {
        guard let context = extensionContext else { return nil }
        let selector = NSSelectorFromString("sourceApplicationBundleIdentifier")
        guard (context as AnyObject).responds(to: selector) else {
            shareLog("Source application bundle not available on this OS version")
            return nil
        }

        guard
            let unmanaged = (context as AnyObject).perform(selector),
            let bundleId = unmanaged.takeUnretainedValue() as? String
        else {
            shareLog("Source application bundle lookup returned nil")
            return nil
        }

        return bundleId
    }

    open override func didSelectPost() {
        shareLog("didSelectPost invoked")
        pendingPostMessage = contentText
        maybeFinalizeShare()
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        hideDefaultUI()
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        suppressKeyboard()
        hideDefaultUI()

        // Prevent re-processing attachments if already done (e.g., sheet bounce-back)
        if hasProcessedAttachments {
            shareLog("⏸️️ viewDidAppear called again - attachments already processed, skipping")
            return
        }

        guard let content = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = content.attachments else {
            shareLog("No attachments found on extension context")
            return
        }

        // Mark as processed to prevent re-runs
        hasProcessedAttachments = true

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

        // Update progress to show ScrapingBee activity (don't stop rotation)
        DispatchQueue.main.async { [weak self] in
            self?.targetProgress = 0.10
            shareLog("Progress: 10% - Fetching your photo...")
        }

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

            // Update progress to show image download starting (don't stop rotation)
            DispatchQueue.main.async { [weak self] in
                self?.targetProgress = 0.20
                shareLog("Progress: 20% - Downloading photo...")
            }

            self.downloadInstagramImages(
                imageUrls,
                originalURL: instagramUrl,
                session: session,
                completion: deliver
            )
        }.resume()
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideDefaultUI()
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
        guard pendingAttachmentCount == 0, !hasQueuedRedirect else {
            shareLog("⏸️️ maybeFinalizeShare: waiting (pending=\(pendingAttachmentCount), hasQueued=\(hasQueuedRedirect))")
            return
        }

        // Don't auto-redirect if we're attempting or showing detection results
        if shouldAttemptDetection || isShowingDetectionResults {
            shareLog("⏸️️ maybeFinalizeShare: BLOCKED - detection in progress (attempt=\(shouldAttemptDetection), showing=\(isShowingDetectionResults))")
            return
        }

        shareLog("✅ maybeFinalizeShare: proceeding with normal redirect")
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

            // Check if detection is configured
            let hasDetectionConfig = detectorEndpoint() != nil && serpApiKey() != nil

            // If detection is configured, start smooth progress animation early
            if hasDetectionConfig {
                DispatchQueue.main.async { [weak self] in
                    // Stop the default status polling since we're now managing status ourselves
                    self?.stopStatusPolling()

                    self?.startSmoothProgress()
                    self?.targetProgress = 0.05

                    // Start rotating status messages for the fetch phase
                    let fetchMessages = [
                        "Fetching your photo...",
                        "Downloading image..."
                    ]
                    self?.startStatusRotation(messages: fetchMessages, interval: 2.5)
                }
            }

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
                    completion()
                case .failure(let error):
                    shareLog("ERROR: Instagram download failed - \(error.localizedDescription)")

                    if hasDetectionConfig {
                        // Detection is configured but ScrapingBee failed - show error instead of redirecting
                        shareLog("Detection is configured but Instagram download failed - showing error")
                        DispatchQueue.main.async {
                            self.showConfigurationError()
                        }
                        // Don't call completion - prevents redirect
                    } else {
                        // No detection configured - fall back to normal flow
                        self.appendLiteralShare(item: item, type: type)
                        completion()
                    }
                }
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
            shareLog("⚠️ ScrapingBee API key missing - cannot download Instagram image")
            shareLog("💡 Instagram URL detected but ScrapingBee not configured. Please run the main app first to set up API keys.")
            completion(.failure(makeInstagramError("ScrapingBee API key not configured. Please open the Snaplook app first.")))
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

    // Call detection API with image URL and base64 payload
    private func runDetectionAnalysis(imageUrl: String, imageBase64: String) {
        shareLog("START runDetectionAnalysis - imageUrl: \(imageUrl), base64 length: \(imageBase64.count)")

        guard let endpoint = detectorEndpoint(),
              let serpKey = serpApiKey() else {
            shareLog("ERROR: Detection endpoint or SerpAPI key not configured")
            handleDetectionFailure(reason: "Detection setup is incomplete. Please open Snaplook to finish configuring analysis.")
            return
        }

        shareLog("Detection endpoint: \(endpoint)")
        shareLog("SerpAPI key: \(serpKey.prefix(8))...")
        targetProgress = 0.60

        // Start rotating status messages for the search phase
        let searchMessages = [
            "Searching for products...",
            "Finding similar items...",
            "Analyzing style...",
            "Checking retailers...",
            "Almost there...",
            "Finalizing results...",
            "Preparing your matches..."
        ]
        startStatusRotation(messages: searchMessages, interval: 2.5, stopAtLast: true)

        var requestBody: [String: Any] = [
            "image_url": imageUrl,
            "image_base64": imageBase64,
            "serp_api_key": serpKey,
            "max_results_per_garment": 10
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            shareLog("ERROR: Failed to serialize detection request JSON")
            handleDetectionFailure(reason: "Could not prepare the analysis request. Please try sharing again.")
            return
        }

        shareLog("Request body size: \(jsonData.count) bytes")

        guard let url = URL(string: endpoint) else {
            shareLog("ERROR: Invalid detection endpoint URL: \(endpoint)")
            handleDetectionFailure(reason: "The detection service URL looks invalid. Check your configuration in Snaplook.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 90.0  // Increased from 30s to 90s for multi-garment detection + SerpAPI searches

        shareLog("Sending detection API request to: \(endpoint)")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                shareLog("ERROR: Detection API network error: \(error.localizedDescription)")
                self.handleDetectionFailure(reason: "We couldn't reach the detection service (\(error.localizedDescription)).")
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            shareLog("Detection API response - status code: \(statusCode)")

            guard let data = data else {
                shareLog("ERROR: Detection API response has no data")
                self.handleDetectionFailure(reason: "The detection service responded without data. Please try again.")
                return
            }

            shareLog("Detection API response data size: \(data.count) bytes")

            // Log response preview for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                let preview = responseString.prefix(500)
                shareLog("Detection API response preview: \(preview)")
            }

            guard statusCode == 200 else {
                shareLog("ERROR: Detection API returned non-200 status: \(statusCode)")
                self.handleDetectionFailure(reason: "Detection service returned status \(statusCode).")
                return
            }

            do {
                let decoder = JSONDecoder()
                let detectionResponse = try decoder.decode(DetectionResponse.self, from: data)

                shareLog("Detection response parsed - success: \(detectionResponse.success)")

                if detectionResponse.success {
                    shareLog("SUCCESS: Detection found \(detectionResponse.total_results) results")
                    self.updateProgress(1.0, status: "Analysis complete")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.stopSmoothProgress()
                        self.detectionResults = detectionResponse.results
                        self.isShowingDetectionResults = true

                        // Haptic feedback for successful analysis
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()

                        shareLog("Calling showDetectionResults with \(self.detectionResults.count) items")
                        self.showDetectionResults()
                    }
                } else {
                    shareLog("ERROR: Detection failed - \(detectionResponse.message ?? "Unknown error")")
                    let message = detectionResponse.message ?? "We couldn't find any products to show."
                    self.handleDetectionFailure(reason: message)
                }
            } catch {
                shareLog("ERROR: Failed to parse detection response: \(error.localizedDescription)")
                self.handleDetectionFailure(reason: "We couldn't read the detection results (\(error.localizedDescription)).")
            }
        }

        task.resume()
        shareLog("Detection API task started")
    }

    private func handleDetectionFailure(reason: String) {
        shareLog("Detection failure: \(reason)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.hasQueuedRedirect { return }
            if self.hasPresentedDetectionFailureAlert { return }
            self.hasPresentedDetectionFailureAlert = true
            self.shouldAttemptDetection = false
            self.isShowingDetectionResults = false
            self.stopStatusRotation()
            self.stopSmoothProgress()
            self.activityIndicator?.stopAnimating()
            self.statusLabel?.isHidden = false
            self.statusLabel?.text = reason

            let alert = UIAlertController(
                title: "Analysis Unavailable",
                message: reason,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(
                title: "Open Snaplook",
                style: .default
            ) { _ in
                self.proceedWithNormalFlow()
            })

            alert.addAction(UIAlertAction(
                title: "Cancel Share",
                style: .cancel
            ) { _ in
                self.closeExtension()
            })

            if self.presentedViewController == nil {
                self.present(alert, animated: true)
            }
        }
    }

    @discardableResult
    private func addResultsHeaderIfNeeded() -> UIView? {
        guard let overlay = loadingView else { return nil }

        if headerContainerView == nil {
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false

            let logo = UIImageView(image: UIImage(named: "logo"))
            logo.contentMode = .left
            logo.clipsToBounds = true
            logo.translatesAutoresizingMaskIntoConstraints = false
            logo.setContentHuggingPriority(.required, for: .horizontal)
            logo.setContentCompressionResistancePriority(.required, for: .horizontal)

            let cancelButton: UIButton
            if let existingButton = cancelButtonView {
                cancelButton = existingButton
            } else {
                let button = UIButton(type: .system)
                button.setTitle("Cancel", for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 16)
                button.addTarget(self, action: #selector(cancelImportTapped), for: .touchUpInside)
                cancelButton = button
            }
            cancelButton.translatesAutoresizingMaskIntoConstraints = false
            cancelButton.setContentHuggingPriority(.required, for: .horizontal)
            cancelButtonView = cancelButton

            container.addSubview(logo)
            container.addSubview(cancelButton)

            overlay.addSubview(container)

            NSLayoutConstraint.activate([
                container.leadingAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                container.trailingAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.trailingAnchor, constant: -16),
                container.topAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.topAnchor, constant: 12),
                container.heightAnchor.constraint(equalToConstant: 40),

                logo.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                logo.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                logo.heightAnchor.constraint(equalToConstant: 28),

                cancelButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                cancelButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                cancelButton.leadingAnchor.constraint(greaterThanOrEqualTo: logo.trailingAnchor, constant: 16),
                cancelButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 28)
            ])

            headerContainerView = container
            headerLogoImageView = logo
        }

        headerContainerView?.isHidden = false
        return headerContainerView
    }

    private func removeResultsHeader() {
        headerLogoImageView = nil
        headerContainerView?.removeFromSuperview()
        headerContainerView = nil
        cancelButtonView = nil
    }

    // Upload image to ImgBB and trigger detection
    private func uploadAndDetect(imageData: Data) {
        shareLog("START uploadAndDetect - image size: \(imageData.count) bytes")

        // Stop status polling since we're now in detection mode
        stopStatusPolling()
        hasPresentedDetectionFailureAlert = false

        // Progress should already be started and at ~0.20 from Instagram download
        // Continue the smooth progress animation
        updateProgress(0.25, status: "Uploading photo...")

        let base64Image = imageData.base64EncodedString()
        shareLog("Base64 encoded - length: \(base64Image.count) chars")

        let apiKey = "d7e1d857e4498c2e28acaa8d943ccea8"

        // Build URL with API key as query parameter
        guard var components = URLComponents(string: "https://api.imgbb.com/1/upload") else {
            shareLog("ERROR: Failed to create ImgBB URL components")
            handleDetectionFailure(reason: "Couldn't prepare the upload request. Please try again.")
            return
        }

        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let url = components.url else {
            shareLog("ERROR: Failed to build ImgBB URL")
            handleDetectionFailure(reason: "Encountered an invalid upload URL. Please try again.")
            return
        }

        // Create multipart/form-data request
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45.0  // Increased from 30s for larger images
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()

        // Add image field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"\r\n\r\n".data(using: .utf8)!)
        body.append(base64Image.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        shareLog("Sending ImgBB multipart upload request with \(body.count) bytes body...")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                shareLog("ERROR: ImgBB upload network error: \(error.localizedDescription)")
                self.handleDetectionFailure(reason: "Upload failed (\(error.localizedDescription)).")
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            shareLog("ImgBB response - status code: \(statusCode)")

            guard let data = data else {
                shareLog("ERROR: ImgBB response has no data")
                self.handleDetectionFailure(reason: "Upload response was empty. Please try again.")
                return
            }

            shareLog("ImgBB response data size: \(data.count) bytes")

            // Log the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                let preview = responseString.prefix(500)
                shareLog("ImgBB response preview: \(preview)")
            }

            guard statusCode == 200 else {
                shareLog("ERROR: ImgBB returned non-200 status: \(statusCode)")
                self.handleDetectionFailure(reason: "Upload service returned status \(statusCode).")
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                shareLog("ERROR: Failed to parse ImgBB JSON")
                self.handleDetectionFailure(reason: "Upload response was unreadable. Please try again.")
                return
            }

            shareLog("ImgBB JSON parsed successfully")

            guard let dataDict = json["data"] as? [String: Any] else {
                shareLog("ERROR: ImgBB response missing 'data' key")
                if let success = json["success"] as? Bool, !success {
                    if let errorDict = json["error"] as? [String: Any],
                       let message = errorDict["message"] as? String {
                        shareLog("ERROR: ImgBB API error: \(message)")
                    }
                }
                self.handleDetectionFailure(reason: "Upload response was missing data. Please try again.")
                return
            }

            guard let imageUrl = dataDict["url"] as? String else {
                shareLog("ERROR: ImgBB data dict missing 'url' key")
                self.handleDetectionFailure(reason: "Upload did not return a URL. Please try again.")
                return
            }

            shareLog("SUCCESS: ImgBB upload complete: \(imageUrl)")
            self.downloadedImageUrl = imageUrl

            // Trigger detection
            self.targetProgress = 0.25
            shareLog("Calling runDetectionAnalysis...")

            // Start rotating status messages for the detection phase
            let detectionMessages = [
                "Detecting garments...",
                "Analyzing clothing...",
                "Identifying items..."
            ]
            self.startStatusRotation(messages: detectionMessages, interval: 2.5)

            self.runDetectionAnalysis(imageUrl: imageUrl, imageBase64: base64Image)
        }

        task.resume()
        shareLog("ImgBB upload task started")
    }

    // Update status label helper
    private func updateStatusLabel(_ text: String) {
        if isPhotosSourceApp {
            enforcePhotosStatusIfNeeded()
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.statusLabel?.text = text
        }
    }

    // Show detection results in table view
    private func showDetectionResults() {
        guard !detectionResults.isEmpty else { return }

        // Prevent re-creating UI if already showing results
        if resultsTableView != nil {
            shareLog("⏸️️ showDetectionResults called again - results already displayed, skipping UI creation")
            return
        }

        shareLog("Showing \(detectionResults.count) detection results")

        // REQUEST EXTENDED EXECUTION TIME to prevent iOS from killing the extension
        // while user is browsing results. Critical for real device stability.
        requestExtendedExecution()

        // Hide loading indicator
        activityIndicator?.stopAnimating()
        activityIndicator?.isHidden = true
        statusLabel?.isHidden = true

        // Initialize filtered results
        filteredResults = detectionResults
        selectedCategory = "All"

        // Create category filter chips
        let filterView = createCategoryFilters()
        categoryFilterView = filterView

        // Create table view if not exists
        if resultsTableView == nil {
            let tableView = UITableView(frame: .zero, style: .plain)
            tableView.translatesAutoresizingMaskIntoConstraints = false
            tableView.delegate = self
            tableView.dataSource = self
            tableView.register(ResultCell.self, forCellReuseIdentifier: "ResultCell")
            tableView.rowHeight = UITableView.automaticDimension
            tableView.estimatedRowHeight = 100
            tableView.backgroundColor = .systemBackground
            tableView.separatorStyle = .singleLine
            tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

            resultsTableView = tableView
        }

        // Create bottom bar with Save All button
        let bottomBarContainer = UIView()
        bottomBarContainer.backgroundColor = .systemBackground
        bottomBarContainer.translatesAutoresizingMaskIntoConstraints = false

        // Separator line
        let separator = UIView()
        separator.backgroundColor = UIColor.systemGray5
        separator.translatesAutoresizingMaskIntoConstraints = false

        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Save", for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        saveButton.backgroundColor = UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 10
        saveButton.addTarget(self, action: #selector(saveAllTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        bottomBarContainer.addSubview(separator)
        bottomBarContainer.addSubview(saveButton)

        let headerView = addResultsHeaderIfNeeded()
        let filterTopAnchor: NSLayoutYAxisAnchor
        let filterTopPadding: CGFloat
        if let headerView = headerView {
            filterTopAnchor = headerView.bottomAnchor
            filterTopPadding = 12
        } else {
            filterTopAnchor = loadingView!.safeAreaLayoutGuide.topAnchor
            filterTopPadding = 0
        }

        // Add all views to loadingView
        loadingView?.addSubview(filterView)
        if let tableView = resultsTableView {
            loadingView?.addSubview(tableView)
        }
        loadingView?.addSubview(bottomBarContainer)
        if let headerView = headerView {
            loadingView?.bringSubviewToFront(headerView)
        }

        // Layout constraints
        NSLayoutConstraint.activate([
            filterView.topAnchor.constraint(equalTo: filterTopAnchor, constant: filterTopPadding),
            filterView.leadingAnchor.constraint(equalTo: loadingView!.leadingAnchor),
            filterView.trailingAnchor.constraint(equalTo: loadingView!.trailingAnchor),
            filterView.heightAnchor.constraint(equalToConstant: 60),

            resultsTableView!.topAnchor.constraint(equalTo: filterView.bottomAnchor),
            resultsTableView!.leadingAnchor.constraint(equalTo: loadingView!.leadingAnchor),
            resultsTableView!.trailingAnchor.constraint(equalTo: loadingView!.trailingAnchor),
            resultsTableView!.bottomAnchor.constraint(equalTo: bottomBarContainer.topAnchor),

            bottomBarContainer.leadingAnchor.constraint(equalTo: loadingView!.leadingAnchor),
            bottomBarContainer.trailingAnchor.constraint(equalTo: loadingView!.trailingAnchor),
            bottomBarContainer.bottomAnchor.constraint(equalTo: loadingView!.safeAreaLayoutGuide.bottomAnchor),
            bottomBarContainer.heightAnchor.constraint(equalToConstant: 90),

            separator.topAnchor.constraint(equalTo: bottomBarContainer.topAnchor),
            separator.leadingAnchor.constraint(equalTo: bottomBarContainer.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: bottomBarContainer.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            saveButton.topAnchor.constraint(equalTo: bottomBarContainer.topAnchor, constant: 16),
            saveButton.leadingAnchor.constraint(equalTo: bottomBarContainer.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: bottomBarContainer.trailingAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 56)
        ])

        resultsTableView?.reloadData()
    }

    private func createCategoryFilters() -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Extract unique categories from results and map to display names
        var uniqueCategories = Set<String>()
        for result in detectionResults {
            let displayCategory = categoryDisplayName(for: result.category)
            uniqueCategories.insert(displayCategory)
        }

        // Sort categories in a logical order
        let categoryOrder = ["Tops", "Bottoms", "Dresses", "Outerwear", "Shoes", "Bags", "Accessories", "Headwear"]
        let sortedCategories = categoryOrder.filter { uniqueCategories.contains($0) }

        // Always start with "All"
        var categories = ["All"]
        categories.append(contentsOf: sortedCategories)

        for category in categories {
            let button = UIButton(type: .system)
            button.setTitle(category, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            button.layer.cornerRadius = 16
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.systemGray4.cgColor
            button.backgroundColor = category == "All" ? UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0) : .systemBackground
            button.setTitleColor(category == "All" ? .white : .label, for: .normal)
            button.addTarget(self, action: #selector(categoryFilterTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }

        scrollView.addSubview(stackView)
        containerView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        return containerView
    }

    // Convert server category to display name
    private func categoryDisplayName(for category: String) -> String {
        let lower = category.lowercased()
        switch lower {
        case "tops": return "Tops"
        case "bottoms": return "Bottoms"
        case "dresses": return "Dresses"
        case "outerwear": return "Outerwear"
        case "shoes": return "Shoes"
        case "bags": return "Bags"
        case "accessories": return "Accessories"
        case "headwear": return "Headwear"
        default: return category.capitalized
        }
    }

    @objc private func categoryFilterTapped(_ sender: UIButton) {
        guard let category = sender.titleLabel?.text else { return }

        selectedCategory = category

        // Update button styles
        if let stackView = categoryFilterView?.subviews.first?.subviews.first as? UIStackView {
            for case let button as UIButton in stackView.arrangedSubviews {
                let isSelected = button.titleLabel?.text == category
                button.backgroundColor = isSelected ? UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0) : .systemBackground
                button.setTitleColor(isSelected ? .white : .label, for: .normal)
            }
        }

        // Filter results
        filterResultsByCategory()
    }

    private func filterResultsByCategory() {
        if selectedCategory == "All" {
            filteredResults = detectionResults
        } else {
            // Filter by matching the display name with the result's category
            filteredResults = detectionResults.filter { result in
                categoryDisplayName(for: result.category) == selectedCategory
            }
        }

        resultsTableView?.reloadData()
        shareLog("Filtered to \(filteredResults.count) results for category: \(selectedCategory)")
    }

    @objc private func saveAllTapped() {
        shareLog("Save All button tapped - saving all results and redirecting")

        // End extended execution since we're wrapping up
        endExtendedExecution()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Write the pending image file to shared container
        if let data = pendingImageData, let file = pendingSharedFile {
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
                shareLog("ERROR: Cannot get container URL for Save All")
                return
            }

            let timestamp = Int(Date().timeIntervalSince1970 * 1000)
            let fileName = "instagram_image_\(timestamp)_all.jpg"
            let fileURL = containerURL.appendingPathComponent(fileName)

            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
                try data.write(to: fileURL, options: .atomic)
                shareLog("SAVE ALL: Wrote file to shared container: \(fileURL.path)")

                // Update the shared file path
                var updatedFile = file
                updatedFile.path = fileURL.absoluteString

                // Save all detection results and the file to UserDefaults
                if let defaults = UserDefaults(suiteName: appGroupId) {
                    // Encode all detection results
                    if let resultsData = try? JSONEncoder().encode(detectionResults),
                       let jsonString = String(data: resultsData, encoding: .utf8) {
                        defaults.set(jsonString, forKey: "AllDetectionResults")
                        shareLog("SAVE ALL: Saved \(detectionResults.count) results to UserDefaults")
                    }

                    // Save the file
                    defaults.set(toData(data: [updatedFile]), forKey: kUserDefaultsKey)
                    defaults.synchronize()
                    shareLog("SAVE ALL: Saved file to UserDefaults")
                }
            } catch {
                shareLog("ERROR writing file for Save All: \(error.localizedDescription)")
                return
            }
        }

        // Redirect to app
        loadIds()
        guard let redirectURL = URL(string: "\(kSchemePrefix)-\(hostAppBundleIdentifier):detection-all") else {
            shareLog("ERROR: Failed to build redirect URL for Save All")
            return
        }

        hasQueuedRedirect = true
        shareLog("Redirecting to app with all detection results")
        let minimumDuration = isPhotosSourceApp ? 2.0 : 0.0
        enqueueRedirect(to: redirectURL, minimumDuration: minimumDuration) { [weak self] in
            self?.finishExtensionRequest()
        }
    }

    @objc private func doneButtonTapped() {
        shareLog("Done button tapped - closing extension")
        closeExtension()
    }

    // Public method that can be called from WebViewController to close the entire extension
    func closeExtension() {
        shareLog("Closing share extension")

        // End extended execution
        endExtendedExecution()

        // Immediately hide default UI to prevent flash
        hideDefaultUI()

        // Clean up state
        loadingHideWorkItem?.cancel()
        loadingHideWorkItem = nil
        isShowingDetectionResults = false
        shouldAttemptDetection = false
        detectionResults.removeAll()
        filteredResults.removeAll()
        pendingImageData = nil
        pendingSharedFile = nil
        pendingImageUrl = nil

        clearSharedData()
        hideLoadingUI()

        // Complete the extension request - this dismisses the share sheet and returns to source app
        let error = NSError(
            domain: "com.snaplook.shareExtension",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "User cancelled"]
        )
        didCompleteRequest = true
        extensionContext?.cancelRequest(withError: error)
        shareLog("Extension closed - user returned to source app")
    }

    // Proceed with normal flow (save and redirect to app)
    private func proceedWithNormalFlow() {
        guard !hasQueuedRedirect else {
            shareLog("⚠️ proceedWithNormalFlow called but redirect already queued")
            return
        }
        shareLog("🔄 Proceeding with normal flow (detection failed or no results)")
        isShowingDetectionResults = false
        shouldAttemptDetection = false
        hasQueuedRedirect = true

        // NOW write the file to shared container so Flutter can pick it up
        if let data = pendingImageData, let file = pendingSharedFile {
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
                shareLog("❌ ERROR: Cannot get container URL for normal flow")
                saveAndRedirect()
                return
            }

            let timestamp = Int(Date().timeIntervalSince1970 * 1000)
            let fileName = "instagram_image_\(timestamp)_fallback.jpg"
            let fileURL = containerURL.appendingPathComponent(fileName)

            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
                try data.write(to: fileURL, options: .atomic)
                shareLog("💾 NORMAL FLOW: Wrote file to shared container: \(fileURL.path)")

                // Update the shared file path
                var updatedFile = file
                updatedFile.path = fileURL.absoluteString

                // Save to UserDefaults
                let userDefaults = UserDefaults(suiteName: appGroupId)
                userDefaults?.set(toData(data: [updatedFile]), forKey: kUserDefaultsKey)
                userDefaults?.synchronize()
                shareLog("💾 NORMAL FLOW: Saved file to UserDefaults")
            } catch {
                shareLog("❌ ERROR writing file in normal flow: \(error.localizedDescription)")
            }
        }

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

        // 🆕 Only pick one image by index
        let userSelectedIndex = UserDefaults.standard.integer(forKey: "InstagramImageIndex") // default 0
        let safeIndex = min(max(userSelectedIndex, 0), uniqueUrls.count - 1)
        let selectedUrl = uniqueUrls[safeIndex]
        shareLog("✅ Selected Instagram image index \(safeIndex) of \(uniqueUrls.count): \(selectedUrl)")

        // 🆕 Download just that one image
        downloadSingleImage(
            urlString: selectedUrl,
            originalURL: originalURL,
            containerURL: containerURL,
            session: session,
            index: safeIndex
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
                session.invalidateAndCancel()
                completion(.failure(error))
            }
        }
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

            // Check if we should attempt detection BEFORE writing file
            let hasDetectionConfig = self.detectorEndpoint() != nil && self.serpApiKey() != nil

            if hasDetectionConfig {
                shareLog("DETECTION CONFIGURED - Holding file in memory, NOT writing to shared container yet")
                self.shouldAttemptDetection = true
                self.pendingImageData = data
                self.pendingImageUrl = originalURL

                // Create shared file reference but DON'T write to disk yet
                let sharedFile = SharedMediaFile(
                    path: fileURL.absoluteString,
                    mimeType: "image/jpeg",
                    message: originalURL,
                    type: .image
                )
                self.pendingSharedFile = sharedFile

                shareLog("Calling uploadAndDetect with \(data.count) bytes of image data")
                // Upload to ImgBB and trigger detection (async - don't complete yet)
                self.uploadAndDetect(imageData: data)

                // DON'T call completion and DON'T write file - wait for detection results or failure
                shareLog("File held in memory. Completion held. uploadAndDetect called.")
            } else {
                shareLog("⚠️ Detection NOT configured - proceeding with normal flow")

                do {
                    // Write file to shared container (normal flow)
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        try FileManager.default.removeItem(at: fileURL)
                    }
                    try data.write(to: fileURL, options: .atomic)
                    shareLog("💾 Saved Instagram image to shared container: \(fileURL.path)")

                    let sharedFile = SharedMediaFile(
                        path: fileURL.absoluteString,
                        mimeType: "image/jpeg",
                        message: originalURL,
                        type: .image
                    )

                    // No detection - complete normally
                    completion(.success(sharedFile))
                } catch {
                    completion(.failure(error))
                }
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

    private func enqueueRedirect(
        to url: URL,
        minimumDuration: TimeInterval,
        completion: @escaping () -> Void
    ) {
        loadingHideWorkItem?.cancel()
        let elapsed = loadingShownAt.map { Date().timeIntervalSince($0) } ?? 0
        let delay = max(0, minimumDuration - elapsed)
        shareLog("Redirect scheduled in \(delay) seconds (elapsed: \(elapsed)) -> \(url.absoluteString)")

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.loadingHideWorkItem = nil
            self.performRedirect(to: url)
            completion()
        }

        loadingHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func redirectToHostApp(sessionId: String) {
        loadIds()
        guard let redirectURL = URL(string: "\(kSchemePrefix)-\(hostAppBundleIdentifier):share") else {
            shareLog("ERROR: Failed to build redirect URL")
            dismissWithError()
            return
        }

        let minimumDuration: TimeInterval = isPhotosSourceApp ? 2.0 : 0.5
        enqueueRedirect(to: redirectURL, minimumDuration: minimumDuration) { [weak self] in
            self?.finishExtensionRequest()
        }
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

    private func showConfigurationError() {
        shareLog("Showing configuration error")
        hideLoadingUI()
        stopStatusPolling()

        let alert = UIAlertController(
            title: "Configuration Required",
            message: "Please open the Snaplook app first to complete setup. Instagram image detection requires API keys to be configured.",
            preferredStyle: .alert
        )

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            guard let self = self else { return }
            let error = NSError(
                domain: "com.snaplook.shareExtension",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Configuration required"]
            )
            self.didCompleteRequest = true
            self.extensionContext?.cancelRequest(withError: error)
        }

        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
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

    private func enforcePhotosStatusIfNeeded() {
        guard isPhotosSourceApp else { return }
        stopStatusRotation()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.statusLabel?.text = self.photoImportStatusMessage
        }
    }

    private func setupLoadingUI() {
        let overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor.systemBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false

        let activity = UIActivityIndicatorView(style: .large)
        activity.startAnimating()
        activityIndicator = activity
        stack.addArrangedSubview(activity)

        let status = UILabel()
        status.text = "Preparing analysis..."
        status.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        status.textAlignment = .center
        status.textColor = UIColor.label
        status.numberOfLines = 2
        stack.addArrangedSubview(status)
        statusLabel = status

        // Add shimmer animation to status label
        DispatchQueue.main.async { [weak self] in
            self?.addShimmerAnimation(to: status)
        }

        // Progress bar
        let progress = UIProgressView(progressViewStyle: .default)
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.progressTintColor = UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0)
        progress.trackTintColor = UIColor.systemGray5
        progress.layer.cornerRadius = 3
        progress.clipsToBounds = true
        progress.setProgress(0.0, animated: false)
        progressView = progress
        stack.addArrangedSubview(progress)

        NSLayoutConstraint.activate([
            progress.widthAnchor.constraint(equalToConstant: 180),
            progress.heightAnchor.constraint(equalToConstant: 6)
        ])

        overlay.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
        ])

        overlay.tag = 9999 // Tag to identify our custom view
        view.addSubview(overlay)
        loadingView = overlay
        loadingShownAt = Date()

        if let header = addResultsHeaderIfNeeded() {
            overlay.bringSubviewToFront(header)
        }

        // Ensure default UI stays hidden
        hideDefaultUI()
    }

    private func startSmoothProgress() {
        stopSmoothProgress()

        currentProgress = 0.0
        targetProgress = 0.0

        DispatchQueue.main.async { [weak self] in
            self?.progressView?.setProgress(0.0, animated: false)

            self?.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
                guard let self = self else { return }

                // Smoothly increment toward target
                if self.currentProgress < self.targetProgress {
                    let increment: Float = 0.008 // Smooth increments
                    self.currentProgress = min(self.currentProgress + increment, self.targetProgress)
                    self.progressView?.setProgress(self.currentProgress, animated: true)
                } else if self.currentProgress < 0.95 {
                    // Slow automatic progress even when waiting (but never reach 100%)
                    let slowIncrement: Float = 0.001
                    self.currentProgress = min(self.currentProgress + slowIncrement, self.targetProgress + 0.05, 0.95)
                    self.progressView?.setProgress(self.currentProgress, animated: true)
                }
            }
        }
    }

    private func stopSmoothProgress() {
        progressTimer?.invalidate()
        progressTimer = nil
        stopStatusRotation()
    }

    private func updateProgress(_ progress: Float, status: String) {
        targetProgress = progress

        if isPhotosSourceApp {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.statusLabel?.text = self.photoImportStatusMessage
                shareLog("Progress: \(Int(progress * 100))% - \(status)")
            }
            stopStatusRotation()
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.statusLabel?.text = status
            shareLog("Progress: \(Int(progress * 100))% - \(status)")
        }

        // Stop any existing rotation when explicitly setting a status
        stopStatusRotation()
    }

    // Start rotating through multiple status messages
    private func startStatusRotation(messages: [String], interval: TimeInterval = 2.5, stopAtLast: Bool = false) {
        guard !messages.isEmpty else { return }

        if isPhotosSourceApp {
            enforcePhotosStatusIfNeeded()
            return
        }

        stopStatusRotation()

        currentStatusMessages = messages
        currentStatusIndex = 0

        // Set first message immediately
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.statusLabel?.text = messages[0]
            shareLog("Status: \(messages[0])")
        }

        // Only start timer if we have multiple messages
        guard messages.count > 1 else { return }

        DispatchQueue.main.async { [weak self] in
            self?.statusRotationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self = self else { return }

                // Move to next message
                if stopAtLast && self.currentStatusIndex >= self.currentStatusMessages.count - 1 {
                    // Already at last message, stop rotation
                    self.stopStatusRotation()
                    return
                }

                self.currentStatusIndex = stopAtLast
                    ? self.currentStatusIndex + 1
                    : (self.currentStatusIndex + 1) % self.currentStatusMessages.count
                let message = self.currentStatusMessages[self.currentStatusIndex]

                // Animate the text change
                UIView.transition(with: self.statusLabel ?? UILabel(),
                                duration: 0.3,
                                options: .transitionCrossDissolve,
                                animations: {
                    self.statusLabel?.text = message
                }, completion: nil)

                shareLog("Status rotated: \(message)")
            }
        }
    }

    private func stopStatusRotation() {
        statusRotationTimer?.invalidate()
        statusRotationTimer = nil
        currentStatusMessages.removeAll()
        currentStatusIndex = 0
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

    private func addShimmerAnimation(to label: UILabel) {
        // Remove any existing animations
        label.layer.removeAnimation(forKey: "shimmerAnimation")

        // Create a subtle pulsing opacity animation - similar to Claude's "breathing" text effect
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 0.5
        pulseAnimation.toValue = 1.0
        pulseAnimation.duration = 1.5
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity

        label.layer.add(pulseAnimation, forKey: "shimmerAnimation")
    }

    private func refreshStatusLabel() {
        // Don't override the text - just ensure the shimmer animation is running
        // The actual text is managed by the status rotation system
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let label = self.statusLabel else { return }

            // Ensure shimmer animation is active
            if label.layer.animation(forKey: "shimmerAnimation") == nil {
                self.addShimmerAnimation(to: label)
            }
        }
    }

    private func hideLoadingUI() {
        loadingHideWorkItem?.cancel()
        loadingHideWorkItem = nil
        stopSmoothProgress()
        loadingView?.removeFromSuperview()
        loadingView = nil
        removeResultsHeader()
        activityIndicator?.stopAnimating()
        activityIndicator = nil
        stopStatusPolling()
        statusLabel = nil
        progressView = nil
    }

    @objc private func cancelImportTapped() {
        shareLog("Cancel tapped")

        // End extended execution
        endExtendedExecution()

        // Immediately hide default UI to prevent flash
        hideDefaultUI()

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

    // Request extended execution time from iOS to prevent extension termination
    private func requestExtendedExecution() {
        endExtendedExecution() // Clean up any existing activity first

        let reason = "User browsing detection results"
        shareLog("Requesting extended execution time from iOS")
        backgroundActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: reason
        )
        ProcessInfo.processInfo.performExpiringActivity(withReason: reason) { [weak self] expired in
            guard expired else { return }
            shareLog("Extended execution time expired - iOS is requesting termination")
            // iOS is asking us to wrap up - keep extension alive if the user is still interacting
            DispatchQueue.main.async {
                shareLog("Extended time expired but keeping extension alive for user interaction")
                self?.endExtendedExecution()
            }
        }
        shareLog("Extended execution time granted")
    }

    // End extended execution time
    private func endExtendedExecution() {
        guard let activity = backgroundActivity else { return }
        shareLog("Ending extended execution time")
        ProcessInfo.processInfo.endActivity(activity)
        backgroundActivity = nil
    }

}

// MARK: - Table View Delegate & DataSource
extension RSIShareViewController: UITableViewDelegate, UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredResults.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ResultCell", for: indexPath) as! ResultCell
        let result = filteredResults[indexPath.row]
        cell.configure(with: result)

        // Hide separator for last cell
        if indexPath.row == filteredResults.count - 1 {
            cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)
        } else {
            cell.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        }

        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedResult = filteredResults[indexPath.row]
        shareLog("User selected result: \(selectedResult.product_name)")

        // Open the product URL in a WKWebView inside the modal
        guard let urlString = selectedResult.purchase_url,
              let url = URL(string: urlString) else {
            shareLog("ERROR: Invalid product URL: \(selectedResult.purchase_url ?? "nil")")
            return
        }

        // Create WebViewController
        let webVC = WebViewController(url: url, shareViewController: self)

        // Embed in a navigation controller for the back button
        let navController = UINavigationController(rootViewController: webVC)
        navController.modalPresentationStyle = .fullScreen

        // Present modally so it appears on top of the loadingView overlay
        present(navController, animated: true) {
            NSLog("[ShareExtension] Presented WebViewController for URL: \(url.absoluteString)")
        }
    }

    private func saveSelectedResultAndRedirect(_ result: DetectionResultItem) {
        shareLog("✅ USER SELECTED RESULT - saving and redirecting")

        // NOW write the file to shared container
        if let data = pendingImageData, let file = pendingSharedFile {
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
                shareLog("❌ ERROR: Cannot get container URL")
                return
            }

            let timestamp = Int(Date().timeIntervalSince1970 * 1000)
            let fileName = "instagram_image_\(timestamp)_selected.jpg"
            let fileURL = containerURL.appendingPathComponent(fileName)

            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
                try data.write(to: fileURL, options: .atomic)
                shareLog("💾 SELECTED RESULT: Wrote file to shared container: \(fileURL.path)")

                // Update the shared file path
                var updatedFile = file
                updatedFile.path = fileURL.absoluteString

                // Save the selected result to UserDefaults
                if let defaults = UserDefaults(suiteName: appGroupId) {
                    var resultData: [String: Any] = [
                        "product_name": result.product_name,
                        "brand": result.brand ?? "",
                        "price": result.priceValue ?? 0,
                        "image_url": result.image_url,
                        "purchase_url": result.purchase_url ?? "",
                        "category": result.category
                    ]

                    if let priceDisplay = result.priceDisplay {
                        resultData["price_display"] = priceDisplay
                    }

                    if let jsonData = try? JSONSerialization.data(withJSONObject: resultData),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        defaults.set(jsonString, forKey: "SelectedDetectionResult")
                        defaults.synchronize()
                        shareLog("💾 SELECTED RESULT: Saved result metadata to UserDefaults")
                    }

                    // Save the file
                    defaults.set(toData(data: [updatedFile]), forKey: kUserDefaultsKey)
                    defaults.synchronize()
                    shareLog("💾 SELECTED RESULT: Saved file to UserDefaults")
                }
            } catch {
                shareLog("❌ ERROR writing file with selected result: \(error.localizedDescription)")
            }
        }

        // Redirect to app
        loadIds()
        guard let redirectURL = URL(string: "\(kSchemePrefix)-\(hostAppBundleIdentifier):detection") else {
            shareLog("❌ ERROR: Failed to build redirect URL")
            return
        }

        hasQueuedRedirect = true
        shareLog("🚀 Redirecting to app with selected result")
        let minimumDuration = isPhotosSourceApp ? 2.0 : 0.0
        enqueueRedirect(to: redirectURL, minimumDuration: minimumDuration) { [weak self] in
            self?.finishExtensionRequest()
        }
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

    private let brandLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let productNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
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
        // Create a vertical stack for the text labels
        let textStackView = UIStackView(arrangedSubviews: [brandLabel, productNameLabel, priceLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 4
        textStackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(productImageView)
        contentView.addSubview(textStackView)

        NSLayoutConstraint.activate([
            productImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            productImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            productImageView.widthAnchor.constraint(equalToConstant: 80),
            productImageView.heightAnchor.constraint(equalToConstant: 80),

            textStackView.leadingAnchor.constraint(equalTo: productImageView.trailingAnchor, constant: 12),
            textStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            textStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 104)
        ])
    }

    func configure(with result: DetectionResultItem) {
        if let brand = result.brand, !brand.isEmpty {
            brandLabel.text = brand
        } else {
            brandLabel.text = "Snaplook match"
        }
        productNameLabel.text = result.product_name

        if let displayPrice = result.priceDisplay {
            priceLabel.text = displayPrice
        } else if let priceValue = result.priceValue, priceValue > 0 {
            priceLabel.text = String(format: "$%.2f", priceValue)
        } else {
            priceLabel.text = "See store"
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
