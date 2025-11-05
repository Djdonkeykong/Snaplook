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

    var normalizedCategoryAssignment: NormalizedCategoryAssignment {
        CategoryNormalizer.shared.assignment(for: self)
    }

    var normalizedCategories: [NormalizedCategory] {
        normalizedCategoryAssignment.categories
    }

    var normalizedCategoryConfidence: Int {
        normalizedCategoryAssignment.confidence
    }

    var categoryGroup: CategoryGroup {
        CategoryGroup.from(
            normalized: normalizedCategories,
            productName: product_name
        )
    }
}

enum NormalizedCategory: String, CaseIterable, Hashable {
    case tops, bottoms, dresses, outerwear, shoes, bags, accessories, headwear, other

    var displayName: String {
        switch self {
        case .tops: return "Tops"
        case .bottoms: return "Bottoms"
        case .dresses: return "Dresses"
        case .outerwear: return "Outerwear"
        case .shoes: return "Shoes"
        case .bags: return "Bags"
        case .accessories: return "Accessories"
        case .headwear: return "Headwear"
        case .other: return "Other"
        }
    }

    static let preferredOrder: [NormalizedCategory] = [
        .tops, .bottoms, .dresses, .outerwear, .shoes, .bags, .accessories, .headwear, .other
    ]

    init?(displayName: String) {
        let lowered = displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch lowered {
        case "tops": self = .tops
        case "bottoms": self = .bottoms
        case "dresses": self = .dresses
        case "outerwear": self = .outerwear
        case "shoes": self = .shoes
        case "bags": self = .bags
        case "accessories": self = .accessories
        case "headwear": self = .headwear
        case "other": self = .other
        default: return nil
        }
    }
}

private struct CategoryRuleSet {
    let positives: [String]
    let negatives: [String]
}

struct NormalizedCategoryAssignment {
    let categories: [NormalizedCategory]
    let confidence: Int
}

enum CategoryGroup: Hashable {
    case all
    case clothing
    case footwear
    case accessories

    var displayName: String {
        switch self {
        case .all: return "All"
        case .clothing: return "Clothing"
        case .footwear: return "Footwear"
        case .accessories: return "Accessories"
        }
    }

    init?(title: String) {
        switch title.lowercased() {
        case "all": self = .all
        case "clothing": self = .clothing
        case "footwear": self = .footwear
        case "accessories": self = .accessories
        default: return nil
        }
    }

    static let orderedGroups: [CategoryGroup] = [.clothing, .footwear, .accessories]

    static func from(normalized: [NormalizedCategory], productName: String) -> CategoryGroup {
        let normalizedSet = Set(normalized)

        if normalizedSet.contains(.shoes) {
            return .footwear
        }

        if !normalizedSet.intersection(clothingCategories).isEmpty {
            return .clothing
        }

        if !normalizedSet.intersection(accessoryCategories).isEmpty {
            return .accessories
        }

        let lowerTitle = productName.lowercased()
        if footwearKeywords.contains(where: lowerTitle.contains) {
            return .footwear
        }

        if clothingKeywords.contains(where: lowerTitle.contains) {
            return .clothing
        }

        return .accessories
    }

    private static let clothingCategories: Set<NormalizedCategory> = [
        .tops, .bottoms, .dresses, .outerwear
    ]

    private static let accessoryCategories: Set<NormalizedCategory> = [
        .bags, .accessories, .headwear, .other
    ]

    private static let footwearKeywords: [String] = [
        "shoe", "boot", "heel", "sandal", "pump", "loafer", "sneaker",
        "trainer", "stiletto", "mule", "platform", "slipper"
    ]

    private static let clothingKeywords: [String] = [
        "dress", "gown", "skirt", "top", "shirt", "blouse", "jacket",
        "coat", "hoodie", "sweater", "pant", "trouser", "jean", "short"
    ]
}

final class CategoryNormalizer {
    static let shared = CategoryNormalizer()

    private let baseMappings: [String: NormalizedCategory] = [
        "tops": .tops,
        "top": .tops,
        "shirts": .tops,
        "shirt": .tops,
        "blouse": .tops,
        "tees": .tops,
        "t-shirts": .tops,
        "bottoms": .bottoms,
        "pants": .bottoms,
        "trousers": .bottoms,
        "jeans": .bottoms,
        "shorts": .bottoms,
        "skirts": .bottoms,
        "dresses": .dresses,
        "dress": .dresses,
        "outerwear": .outerwear,
        "jackets": .outerwear,
        "coats": .outerwear,
        "shoes": .shoes,
        "footwear": .shoes,
        "bags": .bags,
        "bag": .bags,
        "accessories": .accessories,
        "headwear": .headwear,
        "hats": .headwear
    ]

    private let ruleSets: [NormalizedCategory: CategoryRuleSet] = [
        .tops: CategoryRuleSet(
            positives: ["top", "tee", "t-shirt", "shirt", "blouse", "sweater", "hoodie", "cardigan", "pullover", "tank", "camisole"],
            negatives: ["dress", "skirt", "pant", "shoe", "bag", "shorts", "trouser"]
        ),
        .bottoms: CategoryRuleSet(
            positives: ["pant", "jean", "trouser", "short", "skirt", "legging", "culotte", "jogger", "denim", "bottom"],
            negatives: ["dress", "bag", "shoe", "top", "shirt", "hoodie"]
        ),
        .dresses: CategoryRuleSet(
            positives: ["dress", "gown", "maxi", "mini dress", "midi dress", "strapless", "wrap dress", "bodycon"],
            negatives: ["shoe", "bag", "pant", "short", "skirt"]
        ),
        .outerwear: CategoryRuleSet(
            positives: ["coat", "jacket", "blazer", "trench", "parka", "puffer", "outerwear", "windbreaker", "shacket"],
            negatives: ["dress", "skirt", "shoe", "bag"]
        ),
        .shoes: CategoryRuleSet(
            positives: ["shoe", "boot", "sneaker", "heel", "sandal", "pump", "loafer", "mule", "trainer", "cleat"],
            negatives: ["bag", "dress", "skirt", "top"]
        ),
        .bags: CategoryRuleSet(
            positives: ["bag", "handbag", "tote", "crossbody", "satchel", "backpack", "clutch", "shoulder bag", "purse", "duffle"],
            negatives: ["shoe", "dress", "pant"]
        ),
        .accessories: CategoryRuleSet(
            positives: ["belt", "scarf", "sunglass", "bracelet", "necklace", "earring", "ring", "watch", "wallet", "glove", "accessory", "jewelry"],
            negatives: ["shoe", "dress", "pant", "hat", "cap", "beanie"]
        ),
        .headwear: CategoryRuleSet(
            positives: ["hat", "cap", "beanie", "headband", "visor", "beret"],
            negatives: ["bag", "shoe", "dress", "pant"]
        ),
        .other: CategoryRuleSet(
            positives: [],
            negatives: []
        )
    ]

    private let minimumScore = 3

    func assignment(for item: DetectionResultItem) -> NormalizedCategoryAssignment {
        let normalizedCategoryKey = item.category.lowercased()
        var scores: [NormalizedCategory: Int] = [:]

        if let mapped = baseMappings[normalizedCategoryKey] {
            scores[mapped, default: 0] += 3
        }

        let sourceText = [
            item.product_name,
            item.brand ?? "",
            item.description ?? "",
            item.category
        ]
            .joined(separator: " ")
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let tokens: Set<String> = Set(
            sourceText
                .split(separator: " ")
                .map { String($0) }
                .filter { !$0.isEmpty }
        )

        func containsKeyword(_ keyword: String) -> Bool {
            let key = keyword.lowercased()
            if key.contains(" ") {
                return sourceText.contains(key)
            }
            return tokens.contains(key)
        }

        for (category, ruleSet) in ruleSets {
            var score = scores[category, default: 0]
            for keyword in ruleSet.positives where containsKeyword(keyword) {
                score += 2
            }
            for keyword in ruleSet.negatives where containsKeyword(keyword) {
                score -= 3
            }
            scores[category] = score
        }

        // Determine best scores
        let sorted = scores.sorted { $0.value > $1.value }
        let bestScore = sorted.first?.value ?? 0

        var chosen = sorted
            .filter { $0.value >= max(minimumScore, bestScore - 1) && $0.value > 0 }
            .map { $0.key }

        if chosen.isEmpty, let mapped = baseMappings[normalizedCategoryKey] {
            chosen = [mapped]
        }

        if chosen.isEmpty {
            chosen = [.other]
        } else if chosen.count > 2 {
            chosen = Array(chosen.prefix(2))
        }

        if chosen.contains(.other) && chosen.count > 1 {
            chosen.removeAll { $0 == .other }
        }

        return NormalizedCategoryAssignment(
            categories: chosen,
            confidence: max(bestScore, 0)
        )
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
    private var pendingInstagramUrl: String?
    private var pendingInstagramCompletion: (() -> Void)?
    private var analyzedImageData: Data? // Store the analyzed image for sharing
    private var selectedGroup: CategoryGroup? = nil
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

    private static let bannedContentDomainRoots: Set<String> = [
        "facebook.com","instagram.com","twitter.com","x.com","pinterest.com",
        "tiktok.com","linkedin.com","reddit.com","youtube.com","snapchat.com",
        "threads.net","discord.com","wechat.com","weibo.com","line.me","vk.com",
        "blogspot.com","wordpress.com","tumblr.com","medium.com","substack.com",
        "weebly.com","wixsite.com","squarespace.com","ghost.io","notion.site",
        "livejournal.com","typepad.com","quora.com","fandom.com","wikipedia.org",
        "wikihow.com","britannica.com","ask.com","answers.com","bbc.com","cnn.com",
        "nytimes.com","washingtonpost.com","forbes.com","bloomberg.com",
        "reuters.com","huffpost.com","usatoday.com","abcnews.go.com","cbsnews.com",
        "npr.org","time.com","theguardian.com","independent.co.uk","theatlantic.com",
        "vox.com","buzzfeed.com","vice.com","msn.com","dailymail.co.uk","mirror.co.uk",
        "nbcnews.com","latimes.com","insider.com","soundcloud.com","deviantart.com",
        "dribbble.com","artstation.com","behance.net","vimeo.com","bandcamp.com",
        "mixcloud.com","last.fm","spotify.com","goodreads.com","vogue.com","elle.com",
        "harpersbazaar.com","cosmopolitan.com","glamour.com","refinery29.com",
        "whowhatwear.com","instyle.com","graziamagazine.com","vanityfair.com",
        "marieclaire.com","teenvogue.com","stylecaster.com","popsugar.com","nylon.com",
        "lifestyleasia.com","thezoereport.com","allure.com","coveteur.com","thecut.com",
        "dazeddigital.com","highsnobiety.com","hypebeast.com","complex.com","gq.com",
        "esquire.com","menshealth.com","wmagazine.com","people.com","today.com",
        "observer.com","standard.co.uk","eveningstandard.co.uk","nssmag.com",
        "grazia.fr","grazia.it","techcrunch.com","wired.com","theverge.com",
        "engadget.com","gsmarena.com","cnet.com","zdnet.com","mashable.com",
        "makeuseof.com","arstechnica.com","androidauthority.com","macrumors.com",
        "9to5mac.com","digitaltrends.com","imore.com","tomsguide.com",
        "pocket-lint.com","tripadvisor.com","expedia.com","lonelyplanet.com",
        "booking.com","airbnb.com","travelandleisure.com","kayak.com","skyscanner.com"
    ]

    private static func isBannedPurchaseUrl(_ url: String) -> Bool {
        guard let host = URL(string: url)?.host?.lowercased() else { return false }
        for root in bannedContentDomainRoots {
            if host == root || host.hasSuffix(".\(root)") {
                return true
            }
        }
        return false
    }

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

        // Create a completely blank overlay to hide default UI immediately
        let blankOverlay = UIView(frame: view.bounds)
        blankOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blankOverlay.backgroundColor = UIColor.systemBackground
        blankOverlay.tag = 9999
        view.addSubview(blankOverlay)

        // Hide default share extension UI immediately
        hideDefaultUI()

        // Check authentication and build complete UI immediately to prevent white flash
        if !isUserAuthenticated() {
            shareLog("User not authenticated - building login modal in viewDidLoad")
            showLoginRequiredModal()
        } else {
            shareLog("User authenticated - building choice buttons in viewDidLoad")
            addLogoAndCancel()
            showChoiceButtons()
        }
    }

    private func addLogoAndCancel() {
        // Add logo and cancel button to existing blank overlay
        guard let overlay = view.subviews.first(where: { $0.tag == 9999 }) else {
            shareLog("❌ Cannot find blank overlay to add logo/cancel")
            return
        }

        // Add logo and cancel button at top
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.tag = 9996 // Tag to identify header

        let logo = UIImageView(image: UIImage(named: "logo"))
        logo.contentMode = .scaleAspectFit
        logo.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16)
        cancelButton.addTarget(self, action: #selector(cancelImportTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        headerContainer.addSubview(logo)
        headerContainer.addSubview(cancelButton)

        // Add header to overlay
        overlay.addSubview(headerContainer)

        // Set up constraints
        NSLayoutConstraint.activate([
            // Header container
            headerContainer.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: -5),
            headerContainer.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -16),
            headerContainer.topAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.topAnchor, constant: 14),
            headerContainer.heightAnchor.constraint(equalToConstant: 48),

            // Logo
            logo.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            logo.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            logo.heightAnchor.constraint(equalToConstant: 28),
            logo.widthAnchor.constraint(equalToConstant: 132),

            // Cancel button
            cancelButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            cancelButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            cancelButton.leadingAnchor.constraint(greaterThanOrEqualTo: logo.trailingAnchor, constant: 16),
        ])
    }

    private func showChoiceButtons() {
        // Add choice buttons to the existing blank overlay
        guard let overlay = view.subviews.first(where: { $0.tag == 9999 }) else {
            shareLog("❌ Cannot find overlay to add choice buttons")
            return
        }

        // Create vertical stack for buttons
        let buttonStack = UIStackView()
        buttonStack.axis = .vertical
        buttonStack.alignment = .fill
        buttonStack.spacing = 16
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.tag = 9998 // Tag to identify button stack

        // "Analyze in app" button
        let analyzeInAppButton = UIButton(type: .system)
        analyzeInAppButton.setTitle("Analyze in app", for: .normal)
        analyzeInAppButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        analyzeInAppButton.backgroundColor = UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0)
        analyzeInAppButton.setTitleColor(.white, for: .normal)
        analyzeInAppButton.layer.cornerRadius = 28
        analyzeInAppButton.translatesAutoresizingMaskIntoConstraints = false
        analyzeInAppButton.addTarget(self, action: #selector(analyzeInAppTapped), for: .touchUpInside)

        // "Analyze now" button
        let analyzeNowButton = UIButton(type: .system)
        analyzeNowButton.setTitle("Analyze now", for: .normal)
        analyzeNowButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        analyzeNowButton.backgroundColor = .clear
        analyzeNowButton.setTitleColor(.black, for: .normal)
        analyzeNowButton.layer.cornerRadius = 28
        analyzeNowButton.layer.borderWidth = 1.5
        analyzeNowButton.layer.borderColor = UIColor(red: 209/255, green: 213/255, blue: 219/255, alpha: 1.0).cgColor
        analyzeNowButton.translatesAutoresizingMaskIntoConstraints = false
        analyzeNowButton.addTarget(self, action: #selector(analyzeNowTapped), for: .touchUpInside)

        buttonStack.addArrangedSubview(analyzeInAppButton)
        buttonStack.addArrangedSubview(analyzeNowButton)

        // Disclaimer label
        let disclaimerLabel = UILabel()
        disclaimerLabel.text = "Note: Analyzing now analyzes the full image and may use more credits. Analyzing in app lets you crop first to save credits."
        disclaimerLabel.font = .systemFont(ofSize: 12, weight: .regular)
        disclaimerLabel.textColor = UIColor.secondaryLabel
        disclaimerLabel.textAlignment = .center
        disclaimerLabel.numberOfLines = 0
        disclaimerLabel.translatesAutoresizingMaskIntoConstraints = false
        disclaimerLabel.tag = 9997 // Tag for disclaimer

        // Add button stack and disclaimer to overlay
        overlay.addSubview(buttonStack)
        overlay.addSubview(disclaimerLabel)

        // Set up constraints
        NSLayoutConstraint.activate([
            // Button stack (centered)
            buttonStack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            buttonStack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            buttonStack.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 32),
            buttonStack.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -32),

            // Button heights
            analyzeInAppButton.heightAnchor.constraint(equalToConstant: 56),
            analyzeNowButton.heightAnchor.constraint(equalToConstant: 56),

            // Disclaimer at bottom
            disclaimerLabel.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 32),
            disclaimerLabel.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -32),
            disclaimerLabel.bottomAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])

        loadingView = overlay
        hideDefaultUI()
        shareLog("✅ Choice buttons displayed after auth check")
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
        applySheetCornerRadius(12)
        DispatchQueue.main.async { [weak self] in
            self?.applySheetCornerRadius(12)
        }

        // UI is already built in viewDidLoad - just check if we should process attachments
        if !isUserAuthenticated() {
            shareLog("User not authenticated - login modal already displayed")
            return
        }

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
            shareLog("Detected Instagram URL share - showing choice UI before download")

            // Check if detection is configured
            let hasDetectionConfig = detectorEndpoint() != nil && serpApiKey() != nil

            if hasDetectionConfig {
                // Store the Instagram URL and completion for later processing
                pendingInstagramUrl = item
                pendingInstagramCompletion = completion

                // Choice UI is already visible - just wait for user decision
                shareLog("Instagram URL detected - awaiting user decision (buttons already visible)")
                return
            } else {
                // No detection configured - proceed with normal download flow
                shareLog("No detection configured - starting normal Instagram download")
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
                        completion()
                    case .failure(let error):
                        shareLog("ERROR: Instagram download failed - \(error.localizedDescription)")
                        self.appendLiteralShare(item: item, type: type)
                        completion()
                    }
                }
                return
            }
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
    private func runDetectionAnalysis(imageUrl: String?, imageBase64: String) {
        let urlForLog = imageUrl ?? "<nil>"
        shareLog("START runDetectionAnalysis - imageUrl: \(urlForLog), base64 length: \(imageBase64.count)")

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
            "image_base64": imageBase64,
            "serp_api_key": serpKey,
            "max_results_per_garment": 10
        ]

        if let imageUrl = imageUrl, !imageUrl.isEmpty {
            requestBody["image_url"] = imageUrl
        }

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
                        let originalCount = detectionResponse.results.count
                        let filteredResults = detectionResponse.results.filter { result in
                            guard let url = result.purchase_url, !url.isEmpty else { return true }
                            return !Self.isBannedPurchaseUrl(url)
                        }
                        let dropped = originalCount - filteredResults.count
                        if dropped > 0 {
                            shareLog("Filtered out \(dropped) result(s) due to banned domains")
                        }
                        self.detectionResults = filteredResults
                        self.isShowingDetectionResults = true

                        // Haptic feedback for successful analysis
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()

                        shareLog("Calling showDetectionResults with \(self.detectionResults.count) items")
                        for (index, item) in self.detectionResults.prefix(10).enumerated() {
                            let categories = item.normalizedCategories.map { $0.displayName }.joined(separator: ", ")
                            shareLog("Category normalization [\(index)]: \(categories) => \(item.categoryGroup.displayName) (confidence: \(item.normalizedCategoryConfidence)) for \(item.product_name)")
                        }
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

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applySheetCornerRadius(12)
    }

    private func applySheetCornerRadius(_ radius: CGFloat) {
        if #available(iOS 15.0, *) {
            if let sheet = presentationController as? UISheetPresentationController {
                if sheet.preferredCornerRadius != radius {
                    sheet.preferredCornerRadius = radius
                }
            }
        }

        view.layer.cornerRadius = radius
        if #available(iOS 13.0, *) {
            view.layer.cornerCurve = .continuous
        }
        view.layer.masksToBounds = true

        var current = view.superview
        var hops = 0

        while let container = current, hops < 4 {
            container.layer.cornerRadius = radius
            if #available(iOS 13.0, *) {
                container.layer.cornerCurve = .continuous
            }
            container.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            container.layer.masksToBounds = true
            current = container.superview
            hops += 1
        }
    }

    @discardableResult
    private func addResultsHeaderIfNeeded() -> UIView? {
        guard let overlay = loadingView else { return nil }

        if headerContainerView == nil {
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false

            let logo = UIImageView(image: UIImage(named: "logo"))
            logo.contentMode = .scaleAspectFit
            logo.translatesAutoresizingMaskIntoConstraints = false

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
            cancelButtonView = cancelButton

            container.addSubview(logo)
            container.addSubview(cancelButton)

            overlay.addSubview(container)

            NSLayoutConstraint.activate([
                container.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: -5),
                container.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -16),
                container.topAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.topAnchor, constant: 14),
                container.heightAnchor.constraint(equalToConstant: 48),

                logo.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                logo.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                logo.heightAnchor.constraint(equalToConstant: 28),
                logo.widthAnchor.constraint(equalToConstant: 132),

                cancelButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                cancelButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                cancelButton.leadingAnchor.constraint(greaterThanOrEqualTo: logo.trailingAnchor, constant: 16)
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

    // Trigger detection using the Cloudinary-backed API
    private func uploadAndDetect(imageData: Data) {
        shareLog("START uploadAndDetect - image size: \(imageData.count) bytes")

        // Store the image for sharing later
        analyzedImageData = imageData

        // Stop status polling since we're now in detection mode
        stopStatusPolling()
        hasPresentedDetectionFailureAlert = false

        // Progress should already be started from the source fetch; keep things moving
        updateProgress(0.25, status: "Preparing photo...")

        let base64Image = imageData.base64EncodedString()
        shareLog("Base64 encoded - length: \(base64Image.count) chars")

        let resolvedUrl = pendingImageUrl?.isEmpty == false ? pendingImageUrl : downloadedImageUrl
        downloadedImageUrl = resolvedUrl

        targetProgress = 0.25
        shareLog("Calling runDetectionAnalysis...")

        let detectionMessages = [
            "Detecting garments...",
            "Analyzing clothing...",
            "Identifying items..."
        ]
        startStatusRotation(messages: detectionMessages, interval: 2.5)

        runDetectionAnalysis(imageUrl: resolvedUrl, imageBase64: base64Image)
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
        shareLog("=== showDetectionResults START ===")
        shareLog("detectionResults.count: \(detectionResults.count)")
        shareLog("loadingView exists: \(loadingView != nil)")
        shareLog("resultsTableView exists: \(resultsTableView != nil)")

        guard !detectionResults.isEmpty else {
            shareLog("ERROR: detectionResults is empty, returning")
            return
        }

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
        selectedGroup = nil

        shareLog("Creating category filters...")
        // Create category filter chips
        let filterView = createCategoryFilters()
        categoryFilterView = filterView

        shareLog("Creating table view...")
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
            shareLog("Table view created successfully")
        }

        // Create bottom bar with Share and Save buttons
        let bottomBarContainer = UIView()
        bottomBarContainer.backgroundColor = .systemBackground
        bottomBarContainer.translatesAutoresizingMaskIntoConstraints = false

        // Separator line
        let separator = UIView()
        separator.backgroundColor = UIColor.systemGray5
        separator.translatesAutoresizingMaskIntoConstraints = false

        // Share button (secondary style)
        let shareButton = UIButton(type: .system)
        shareButton.setTitle("Share", for: .normal)
        shareButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        shareButton.backgroundColor = .systemBackground
        shareButton.setTitleColor(UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0), for: .normal)
        shareButton.layer.cornerRadius = 28
        shareButton.layer.borderWidth = 2
        shareButton.layer.borderColor = UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0).cgColor
        shareButton.addTarget(self, action: #selector(shareResultsTapped), for: .touchUpInside)
        shareButton.translatesAutoresizingMaskIntoConstraints = false

        // Save button (primary style)
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Save", for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        saveButton.backgroundColor = UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 28
        saveButton.addTarget(self, action: #selector(saveAllTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        bottomBarContainer.addSubview(separator)
        bottomBarContainer.addSubview(shareButton)
        bottomBarContainer.addSubview(saveButton)

        // Layout constraints - safely unwrap FIRST to prevent crashes
        guard let loadingView = loadingView, let tableView = resultsTableView else {
            shareLog("ERROR: loadingView or resultsTableView is nil - cannot display results")
            return
        }

        let headerView = addResultsHeaderIfNeeded()
        let filterTopAnchor: NSLayoutYAxisAnchor
        let filterTopPadding: CGFloat
        if let headerView = headerView {
            filterTopAnchor = headerView.bottomAnchor
            filterTopPadding = 12
        } else {
            filterTopAnchor = loadingView.safeAreaLayoutGuide.topAnchor
            filterTopPadding = 0
        }

        // Add all views to loadingView
        loadingView.addSubview(filterView)
        loadingView.addSubview(tableView)
        loadingView.addSubview(bottomBarContainer)
        if let headerView = headerView {
            loadingView.bringSubviewToFront(headerView)
        }

        NSLayoutConstraint.activate([
            filterView.topAnchor.constraint(equalTo: filterTopAnchor, constant: filterTopPadding),
            filterView.leadingAnchor.constraint(equalTo: loadingView.leadingAnchor),
            filterView.trailingAnchor.constraint(equalTo: loadingView.trailingAnchor),
            filterView.heightAnchor.constraint(equalToConstant: 60),

            tableView.topAnchor.constraint(equalTo: filterView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: loadingView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: loadingView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomBarContainer.topAnchor),

            bottomBarContainer.leadingAnchor.constraint(equalTo: loadingView.leadingAnchor),
            bottomBarContainer.trailingAnchor.constraint(equalTo: loadingView.trailingAnchor),
            bottomBarContainer.bottomAnchor.constraint(equalTo: loadingView.safeAreaLayoutGuide.bottomAnchor),
            bottomBarContainer.heightAnchor.constraint(equalToConstant: 90),

            separator.topAnchor.constraint(equalTo: bottomBarContainer.topAnchor),
            separator.leadingAnchor.constraint(equalTo: bottomBarContainer.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: bottomBarContainer.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            // Share button (left, 50% width)
            shareButton.topAnchor.constraint(equalTo: bottomBarContainer.topAnchor, constant: 16),
            shareButton.leadingAnchor.constraint(equalTo: bottomBarContainer.leadingAnchor, constant: 16),
            shareButton.trailingAnchor.constraint(equalTo: bottomBarContainer.centerXAnchor, constant: -6),
            shareButton.heightAnchor.constraint(equalToConstant: 56),

            // Save button (right, 50% width)
            saveButton.topAnchor.constraint(equalTo: bottomBarContainer.topAnchor, constant: 16),
            saveButton.leadingAnchor.constraint(equalTo: bottomBarContainer.centerXAnchor, constant: 6),
            saveButton.trailingAnchor.constraint(equalTo: bottomBarContainer.trailingAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 56)
        ])

        tableView.reloadData()
        shareLog("Results UI successfully displayed")
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

        let button = UIButton(type: .system)
        button.setTitle(CategoryGroup.all.displayName, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        button.layer.cornerRadius = 18
        button.clipsToBounds = true
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.cgColor
        button.backgroundColor = UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0)
        button.setTitleColor(.white, for: .normal)
        button.isUserInteractionEnabled = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true

        stackView.addArrangedSubview(button)

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
    @objc private func categoryFilterTapped(_ sender: UIButton) {
        // Only "All" chip exists; no filtering required.
        filterResultsByCategory()
    }

    private func filterResultsByCategory() {
        filteredResults = detectionResults
        resultsTableView?.reloadData()
        shareLog("Filtered to \(filteredResults.count) results for category: All")
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

    @objc private func shareResultsTapped() {
        shareLog("Share button tapped - preparing share content")
        shareLog("analyzedImageData exists: \(analyzedImageData != nil)")
        if let data = analyzedImageData {
            shareLog("analyzedImageData size: \(data.count) bytes")
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Get top 5 products for sharing
        let topProducts = Array(detectionResults.prefix(5))
        let totalResults = detectionResults.count

        // Create share text
        var shareText = "I analyzed this look on Snaplook and found \(totalResults) matches! 🔥\n\n"

        if !topProducts.isEmpty {
            shareText += "Top finds:\n"
            for (index, product) in topProducts.enumerated() {
                let productName = product.product_name
                let brand = product.brand ?? "Unknown brand"
                shareText += "\(index + 1). \(brand) - \(productName)\n"
            }
            shareText += "\n"
        }

        shareText += "Get Snaplook to find your fashion matches: https://snaplook.app"

        // Prepare items to share
        var itemsToShare: [Any] = [shareText]

        // Add the analyzed image if available
        if let imageData = analyzedImageData {
            shareLog("Attempting to create UIImage from \(imageData.count) bytes")
            if let image = UIImage(data: imageData) {
                itemsToShare.insert(image, at: 0) // Image first, then text
                shareLog("✅ Successfully added analyzed image to share (size: \(image.size))")
            } else {
                shareLog("❌ ERROR: Failed to create UIImage from imageData")
            }
        } else {
            shareLog("❌ WARNING: analyzedImageData is nil - no image to share")
        }

        // Present iOS share sheet
        let activityVC = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)

        // Exclude some activities that don't make sense
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks
        ]

        // For iPad support
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        present(activityVC, animated: true) {
            shareLog("Share sheet presented successfully")
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

            // User has already made their choice via the choice UI before download started
            // Just write the file and complete
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
            // DON'T hide loading UI - keep it visible to prevent flash of default UI
            // self.hideLoadingUI()
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

                // Safety check: Stop if messages array became empty
                guard !self.currentStatusMessages.isEmpty else {
                    shareLog("Status rotation stopped - messages array is empty")
                    self.stopStatusRotation()
                    return
                }

                // Move to next message
                if stopAtLast && self.currentStatusIndex >= self.currentStatusMessages.count - 1 {
                    // Already at last message, stop rotation
                    self.stopStatusRotation()
                    return
                }

                self.currentStatusIndex = stopAtLast
                    ? self.currentStatusIndex + 1
                    : (self.currentStatusIndex + 1) % self.currentStatusMessages.count

                // Safety check: Ensure index is within bounds
                guard self.currentStatusIndex < self.currentStatusMessages.count else {
                    shareLog("Status index out of bounds - stopping rotation")
                    self.stopStatusRotation()
                    return
                }

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

    // MARK: - Authentication Check

    private func isUserAuthenticated() -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            shareLog("❌ Cannot access UserDefaults for authentication check")
            return false
        }

        // Check for our custom authentication flag
        // The main app will set this when user logs in
        let isAuthenticated = defaults.bool(forKey: "user_authenticated")

        if isAuthenticated {
            shareLog("✅ User authenticated")
        } else {
            shareLog("❌ User not authenticated")
        }

        return isAuthenticated
    }

    private func showLoginRequiredModal() {
        // Haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)

        // Use existing blank overlay or create new one
        let overlay: UIView
        if let existingOverlay = view.subviews.first(where: { $0.tag == 9999 }) {
            overlay = existingOverlay
            // Keep tag as 9999 so hideDefaultUI() doesn't hide it
        } else {
            overlay = UIView(frame: view.bounds)
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            overlay.backgroundColor = UIColor.systemBackground
            overlay.tag = 9999 // Use 9999 so hideDefaultUI() doesn't hide it
        }

        // Add logo and cancel button at top
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false

        let logo = UIImageView(image: UIImage(named: "logo"))
        logo.contentMode = .scaleAspectFit
        logo.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16)
        cancelButton.addTarget(self, action: #selector(cancelLoginRequiredTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        headerContainer.addSubview(logo)
        headerContainer.addSubview(cancelButton)

        // Container for centered content
        let contentContainer = UIView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        // Title
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Sign in required"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label

        // Message
        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = "Please sign in to Snaplook to use the share extension"
        messageLabel.font = .systemFont(ofSize: 15, weight: .regular)
        messageLabel.textAlignment = .center
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0

        // Buttons stack
        let buttonStack = UIStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .vertical
        buttonStack.spacing = 16
        buttonStack.distribution = .fillEqually

        // "Open Snaplook" button (pill-shaped)
        let openAppButton = UIButton(type: .system)
        openAppButton.setTitle("Open Snaplook", for: .normal)
        openAppButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        openAppButton.setTitleColor(.white, for: .normal)
        openAppButton.backgroundColor = UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0)
        openAppButton.layer.cornerRadius = 28
        openAppButton.addTarget(self, action: #selector(openAppTapped), for: .touchUpInside)

        // "Cancel" button (pill-shaped with border)
        let cancelActionButton = UIButton(type: .system)
        cancelActionButton.setTitle("Cancel", for: .normal)
        cancelActionButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        cancelActionButton.setTitleColor(.black, for: .normal)
        cancelActionButton.backgroundColor = .clear
        cancelActionButton.layer.cornerRadius = 28
        cancelActionButton.layer.borderWidth = 1.5
        cancelActionButton.layer.borderColor = UIColor(red: 209/255, green: 213/255, blue: 219/255, alpha: 1.0).cgColor
        cancelActionButton.addTarget(self, action: #selector(cancelLoginRequiredTapped), for: .touchUpInside)

        // Add all subviews to button stack
        buttonStack.addArrangedSubview(openAppButton)
        buttonStack.addArrangedSubview(cancelActionButton)

        // Add all subviews to content container
        contentContainer.addSubview(titleLabel)
        contentContainer.addSubview(messageLabel)
        contentContainer.addSubview(buttonStack)

        // Add all subviews to overlay
        overlay.addSubview(headerContainer)
        overlay.addSubview(contentContainer)

        // Add overlay to view if it's new
        if overlay.superview == nil {
            view.addSubview(overlay)
        }

        // Layout constraints
        NSLayoutConstraint.activate([
            // Header container
            headerContainer.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: -5),
            headerContainer.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -16),
            headerContainer.topAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.topAnchor, constant: 14),
            headerContainer.heightAnchor.constraint(equalToConstant: 48),

            // Logo
            logo.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            logo.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            logo.heightAnchor.constraint(equalToConstant: 28),
            logo.widthAnchor.constraint(equalToConstant: 132),

            // Cancel button in header
            cancelButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            cancelButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            cancelButton.leadingAnchor.constraint(greaterThanOrEqualTo: logo.trailingAnchor, constant: 16),

            // Center content container
            contentContainer.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            contentContainer.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 32),
            contentContainer.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -32),

            // Title
            titleLabel.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),

            // Message
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),

            // Button stack
            buttonStack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 32),
            buttonStack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            buttonStack.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            // Button heights
            openAppButton.heightAnchor.constraint(equalToConstant: 56),
            cancelActionButton.heightAnchor.constraint(equalToConstant: 56),
        ])

        shareLog("✅ Login required modal displayed")
    }

    @objc private func openAppTapped() {
        shareLog("Open App tapped from login modal")

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Save a flag that user needs to sign in
        if let defaults = UserDefaults(suiteName: appGroupId) {
            defaults.set(true, forKey: "needs_signin_from_share_extension")
            defaults.synchronize()
        }

        // Try to open the main app using extensionContext
        if let url = URL(string: "snaplook://auth") {
            extensionContext?.open(url, completionHandler: { [weak self] success in
                shareLog(success ? "✅ Successfully opened app" : "⚠️ Failed to open app (may be simulator limitation)")

                // Always cancel the extension
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.cancelLoginRequiredTapped()
                }
            })
        } else {
            // If URL creation fails, just dismiss
            shareLog("❌ Failed to create app URL")
            cancelLoginRequiredTapped()
        }
    }

    @objc private func cancelLoginRequiredTapped() {
        shareLog("Cancel tapped from login modal")

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Cancel the extension
        let error = NSError(
            domain: "com.snaplook.shareExtension",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]
        )
        extensionContext?.cancelRequest(withError: error)
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

    @objc private func analyzeInAppTapped() {
        shareLog("Analyze in app tapped")

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Remove choice UI
        hideLoadingUI()

        // Check if this is an Instagram URL (before download) or direct image (after download)
        if let instagramUrl = pendingInstagramUrl {
            shareLog("Downloading Instagram media and saving to app")

            // Start download process
            updateProcessingStatus("processing")
            setupLoadingUI()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.startSmoothProgress()
                self.targetProgress = 0.8
                self.updateProgress(0.2, status: "Downloading your photo...")
            }

            // Simulate intermediate progress during download
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.targetProgress = 0.5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.targetProgress = 0.7
            }

            downloadInstagramMedia(from: instagramUrl) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let downloaded):
                    if downloaded.isEmpty {
                        shareLog("Instagram download succeeded but returned no files")
                        self.dismissWithError()
                    } else {
                        self.sharedMedia.append(contentsOf: downloaded)
                        shareLog("Downloaded and saved \(downloaded.count) Instagram file(s)")

                        // Update progress to near completion
                        self.targetProgress = 0.95
                        self.updateProgress(0.95, status: "Opening Snaplook...")

                        // Small delay to show the completion, then redirect
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            self.saveAndRedirect(message: self.pendingInstagramUrl)
                        }
                    }

                    // Call the pending completion
                    self.pendingInstagramCompletion?()
                    self.pendingInstagramCompletion = nil
                    self.pendingInstagramUrl = nil

                case .failure(let error):
                    shareLog("ERROR: Instagram download failed - \(error.localizedDescription)")
                    self.dismissWithError()
                }
            }
        } else if let imageData = pendingImageData,
                  let sharedFile = pendingSharedFile,
                  let fileURL = URL(string: sharedFile.path) {
            shareLog("Saving direct image to app")

            do {
                // Write the file to shared container
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
                try imageData.write(to: fileURL, options: .atomic)
                shareLog("Saved image to shared container: \(fileURL.path)")

                // Add to shared media array
                sharedMedia.append(sharedFile)

                // Open app with the saved file (no detection)
                saveAndRedirect(message: pendingImageUrl)

            } catch {
                shareLog("ERROR: Failed to save image - \(error.localizedDescription)")
            }
        } else {
            shareLog("ERROR: No pending Instagram URL or image data")
        }
    }

    @objc private func analyzeNowTapped() {
        shareLog("Analyze now tapped - starting detection")

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Remove choice UI
        hideLoadingUI()

        // Check if this is an Instagram URL (before download) or direct image (after download)
        if let instagramUrl = pendingInstagramUrl {
            shareLog("Downloading Instagram media and starting detection")

            // Start download process with detection flow
            updateProcessingStatus("processing")
            setupLoadingUI()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                // Stop the default status polling since we're now managing status ourselves
                self.stopStatusPolling()

                self.startSmoothProgress()
                self.targetProgress = 0.05

                // Start rotating status messages for the fetch phase
                let fetchMessages = [
                    "Fetching your photo...",
                    "Downloading image..."
                ]
                self.startStatusRotation(messages: fetchMessages, interval: 2.5)
            }

            downloadInstagramMedia(from: instagramUrl) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let downloaded):
                    if downloaded.isEmpty {
                        shareLog("Instagram download succeeded but returned no files")
                        self.dismissWithError()
                    } else {
                        // Get the first downloaded file and start detection
                        if let firstFile = downloaded.first,
                           let fileURL = URL(string: firstFile.path),
                           let imageData = try? Data(contentsOf: fileURL) {
                            shareLog("Downloaded Instagram image, starting detection with \(imageData.count) bytes")
                            self.uploadAndDetect(imageData: imageData)
                        } else {
                            shareLog("ERROR: Could not read downloaded Instagram file")
                            self.dismissWithError()
                        }
                    }

                    // DON'T call completion - we're analyzing now, not redirecting
                    // The extension will stay open for detection results
                    self.pendingInstagramCompletion = nil
                    self.pendingInstagramUrl = nil

                case .failure(let error):
                    shareLog("ERROR: Instagram download failed - \(error.localizedDescription)")
                    self.dismissWithError()
                }
            }
        } else if let imageData = pendingImageData {
            shareLog("Starting detection on direct image with \(imageData.count) bytes")

            // Start the upload and detection process
            uploadAndDetect(imageData: imageData)
        } else {
            shareLog("ERROR: No pending Instagram URL or image data")
        }
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

    private let favoriteButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        button.setImage(UIImage(systemName: "heart", withConfiguration: config), for: .normal)
        button.setImage(UIImage(systemName: "heart.fill", withConfiguration: config), for: .selected)
        button.tintColor = .black
        button.backgroundColor = UIColor(white: 1.0, alpha: 0.9)
        button.layer.cornerRadius = 16
        button.layer.masksToBounds = false
        button.layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
        button.layer.shadowOpacity = 1
        button.layer.shadowRadius = 3
        button.layer.shadowOffset = CGSize(width: 0, height: 1.5)
        button.adjustsImageWhenHighlighted = false
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        button.imageEdgeInsets = .zero
        return button
    }()
    private var isFavorite = false

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
        contentView.addSubview(favoriteButton)
        contentView.addSubview(textStackView)
        favoriteButton.addTarget(self, action: #selector(favoriteTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            productImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            productImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            productImageView.widthAnchor.constraint(equalToConstant: 80),
            productImageView.heightAnchor.constraint(equalToConstant: 80),

            favoriteButton.bottomAnchor.constraint(equalTo: productImageView.bottomAnchor, constant: -6),
            favoriteButton.trailingAnchor.constraint(equalTo: productImageView.trailingAnchor, constant: -6),
            favoriteButton.widthAnchor.constraint(equalToConstant: 32),
            favoriteButton.heightAnchor.constraint(equalToConstant: 32),

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

        // Reset favorite state for reused cells
        isFavorite = false
        updateFavoriteAppearance(animated: false)
    }

    @objc private func favoriteTapped() {
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()

        isFavorite.toggle()
        updateFavoriteAppearance(animated: true)
    }

    private func updateFavoriteAppearance(animated: Bool) {
        let applyAppearance = {
            self.favoriteButton.isSelected = self.isFavorite
            self.favoriteButton.tintColor = self.isFavorite
                ? UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0)
                : .black
        }

        if animated {
            applyAppearance()
            let expandTransform = CGAffineTransform(scaleX: 1.12, y: 1.12)
            UIView.animate(withDuration: 0.1, animations: {
                self.favoriteButton.transform = expandTransform
            }, completion: { _ in
                UIView.animate(
                    withDuration: 0.25,
                    delay: 0,
                    usingSpringWithDamping: 0.55,
                    initialSpringVelocity: 3.5,
                    options: [.allowUserInteraction, .beginFromCurrentState],
                    animations: {
                        self.favoriteButton.transform = .identity
                    },
                    completion: nil
                )
            })
        } else {
            applyAppearance()
            favoriteButton.transform = .identity
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


