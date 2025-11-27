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
import TOCropViewController

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
            return DetectionResultItem.formatPrice(numeric)
        }
        return nil
    }

    private static let sharedCurrencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = .autoupdatingCurrent
        return formatter
    }()

    private static func formatPrice(_ value: Double) -> String? {
        // Refresh locale in case the user changes region/language
        sharedCurrencyFormatter.locale = .autoupdatingCurrent
        return sharedCurrencyFormatter.string(from: NSNumber(value: value))
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

struct DetectionResponse: Decodable {
    let success: Bool
    let detected_garment: DetectedGarment?
    let total_results: Int
    let results: [DetectionResultItem]
    let message: String?
    let search_id: String?
    let image_cache_id: String?
    let cached: Bool?

    enum CodingKeys: String, CodingKey {
        case success
        case detected_garment
        case detected_garments
        case total_results
        case results
        case search_results
        case message
        case search_id
        case image_cache_id
        case cached
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? container.decode(Bool.self, forKey: .success)) ?? false

        // Handle both old (detected_garment) and new (detected_garments) formats
        if let garments = try? container.decodeIfPresent([DetectedGarment].self, forKey: .detected_garments),
           let firstGarment = garments.first {
            detected_garment = firstGarment
        } else {
            detected_garment = try? container.decodeIfPresent(DetectedGarment.self, forKey: .detected_garment)
        }

        if let total = try? container.decode(Int.self, forKey: .total_results) {
            total_results = total
        } else if let decodedResults = try? container.decode([DetectionResultItem].self, forKey: .results) {
            total_results = decodedResults.count
        } else if let decodedResults = try? container.decode([DetectionResultItem].self, forKey: .search_results) {
            total_results = decodedResults.count
        } else {
            total_results = 0
        }

        // Handle both old (results) and new (search_results) formats
        if let searchResults = try? container.decode([DetectionResultItem].self, forKey: .search_results) {
            results = searchResults
        } else {
            results = (try? container.decode([DetectionResultItem].self, forKey: .results)) ?? []
        }

        message = try? container.decodeIfPresent(String.self, forKey: .message)
        search_id = try? container.decodeIfPresent(String.self, forKey: .search_id)
        image_cache_id = try? container.decodeIfPresent(String.self, forKey: .image_cache_id)
        cached = try? container.decodeIfPresent(Bool.self, forKey: .cached)
    }

    struct DetectedGarment: Decodable {
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
    private var favoritedProductIds: Set<String> = []
    private var favoriteIdByProductId: [String: String] = [:]
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
    private var pendingPlatformType: String?
    private var sourceApplicationBundleId: String?
    private var inferredPlatformType: String?
    private var currentSearchId: String?
    private var currentImageCacheId: String?
    private var analyzedImageData: Data? // Store the analyzed image for sharing
    private var previewImageView: UIImageView? // Reference to preview image for updating after crop
    private var selectedGroup: CategoryGroup? = nil
    private var categoryFilterView: UIView?
    private var hasProcessedAttachments = false
    private var progressView: UIProgressView?
    private var progressTimer: Timer?
    private var currentProgress: Float = 0.0
    private var targetProgress: Float = 0.0
    private var progressRateMultiplier: Float = 1.0
    private var previewTargetCap: Float = 0.92
    private var detectTargetCap: Float = 0.96
    private var statusRotationTimer: Timer?
    private var currentStatusMessages: [String] = []
    private var currentStatusIndex: Int = 0
    private var backgroundActivity: NSObjectProtocol?
    private var hasPresentedDetectionFailureAlert = false
    private var headerContainerView: UIView?
    private var headerLogoImageView: UIImageView?
    private var cancelButtonView: UIButton?
    private let bannedKeywordPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: "\\bwig\\b", options: [.caseInsensitive]),
        try! NSRegularExpression(pattern: "\\bwigs\\b", options: [.caseInsensitive]),
        try! NSRegularExpression(pattern: "\\bwiglets?\\b", options: [.caseInsensitive]),
        try! NSRegularExpression(pattern: "\\bwig[-\\s]?caps?\\b", options: [.caseInsensitive]),
        try! NSRegularExpression(pattern: "\\blace[-\\s]?front\\b", options: [.caseInsensitive])
    ]

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

    private static let browserBundlePlatformMap: [String: String] = [
        "com.apple.mobilesafari": "safari",
        "com.apple.safariviewservice": "safari",
        "com.google.chrome.ios": "chrome",
        "com.google.chrome": "chrome",
        "org.mozilla.ios.firefox": "firefox",
        "org.mozilla.firefox": "firefox",
    ]

    private func detectPlatformType(from bundleId: String) -> String? {
        let normalized = bundleId.lowercased()
        if let mapped = RSIShareViewController.browserBundlePlatformMap[normalized] {
            return mapped
        }
        if normalized.contains("safari") {
            return "safari"
        }
        if normalized.contains("chrome") {
            return "chrome"
        }
        if normalized.contains("firefox") {
            return "firefox"
        }
        return nil
    }

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
            sourceApplicationBundleId = sourceBundle
            let photosBundles: Set<String> = [
                "com.apple.mobileslideshow",
                "com.apple.Photos"
            ]
            if photosBundles.contains(sourceBundle) {
                isPhotosSourceApp = true
                shareLog("Detected Photos source app - enforcing minimum 2s redirect delay")
            }
            if let platform = detectPlatformType(from: sourceBundle) {
                inferredPlatformType = platform
                if pendingPlatformType == nil {
                    pendingPlatformType = platform
                }
                shareLog("Detected browser platform type: \(platform)")
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
        // Block auto-redirect while choice UI is visible
        shouldAttemptDetection = true
        shareLog("Choice buttons shown - blocking auto-redirect")

        // Add choice buttons to the existing blank overlay
        guard let overlay = view.subviews.first(where: { $0.tag == 9999 }) else {
            shareLog("Cannot find overlay to add choice buttons")
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
        analyzeInAppButton.titleLabel?.font = UIFont(name: "PlusJakartaSans-Bold", size: 16)
            ?? .systemFont(ofSize: 16, weight: .bold)
        analyzeInAppButton.backgroundColor = UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0)
        analyzeInAppButton.setTitleColor(.white, for: .normal)
        analyzeInAppButton.layer.cornerRadius = 28
        analyzeInAppButton.translatesAutoresizingMaskIntoConstraints = false
        analyzeInAppButton.addTarget(self, action: #selector(analyzeInAppTapped), for: .touchUpInside)

        // "Analyze now" button
        let analyzeNowButton = UIButton(type: .system)
        analyzeNowButton.setTitle("Analyze now", for: .normal)
        analyzeNowButton.titleLabel?.font = UIFont(name: "PlusJakartaSans-Bold", size: 16)
            ?? .systemFont(ofSize: 16, weight: .bold)
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
        disclaimerLabel.text = "Tip: Cropping can help you save credits because each garment scanned uses one."
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
            URLQueryItem(name: "wait", value: "1500")
        ]

        guard let requestURL = components.url else {
            completion(.failure(makeInstagramError("Failed to build ScrapingBee request URL")))
            return
        }

        shareLog("Fetching Instagram HTML via ScrapingBee (attempt \(attempt + 1)) for \(instagramUrl)")

        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 12.0

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
        // Only process URLs
        guard type == .url else {
            appendLiteralShare(item: item, type: type)
            completion()
            return
        }

        // Determine the platform type
        let platformName: String
        let platformType: String
        let downloadFunction: (String, @escaping (Result<[SharedMediaFile], Error>) -> Void) -> Void

        if isInstagramShareCandidate(item) {
            platformName = "Instagram"
            platformType = "instagram"
            downloadFunction = downloadInstagramMedia
        } else if isTikTokShareCandidate(item) {
            platformName = "TikTok"
            platformType = "tiktok"
            downloadFunction = downloadTikTokMedia
        } else if isPinterestShareCandidate(item) {
            platformName = "Pinterest"
            platformType = "pinterest"
            downloadFunction = downloadPinterestMedia
        } else if isYouTubeShareCandidate(item) {
            platformName = "YouTube"
            platformType = "youtube"
            downloadFunction = downloadYouTubeMedia
        } else if isGoogleImageShareCandidate(item) {
            platformName = "Google Image"
            platformType = "google_image"
            downloadFunction = downloadGoogleImageMedia
        } else if item.lowercased().hasPrefix("http://") || item.lowercased().hasPrefix("https://") {
            // Generic link - try to download images from it
            platformName = "Generic Link"
            platformType = "generic"
            downloadFunction = downloadGenericLinkMedia
        } else {
            // Not a URL we can download from
            appendLiteralShare(item: item, type: type)
            completion()
            return
        }

        shareLog("Detected \(platformName) URL share - showing choice UI before download")

        // Check if detection is configured
        let hasDetectionConfig = detectorEndpoint() != nil && serpApiKey() != nil

        if hasDetectionConfig {
            // Store the URL and completion for later processing
            pendingInstagramUrl = item
            pendingInstagramCompletion = completion
            pendingPlatformType = platformType

            // Choice UI is already visible - just wait for user decision
            shareLog("\(platformName) URL detected - awaiting user decision (buttons already visible)")
            shareLog("DEBUG: Stored pendingInstagramUrl for \(platformName) - URL: \(item.prefix(50))...")
            return
        } else {
            // No detection configured - proceed with normal download flow
            shareLog("No detection configured - starting normal \(platformName) download")
            updateProcessingStatus("processing")

            downloadFunction(item) { [weak self] result in
                guard let self = self else {
                    completion()
                    return
                }

                switch result {
                case .success(let downloaded):
                    if downloaded.isEmpty {
                        shareLog("\(platformName) download succeeded but returned no files - falling back to literal URL")
                        self.appendLiteralShare(item: item, type: type)
                    } else {
                        self.sharedMedia.append(contentsOf: downloaded)
                        shareLog("Appended \(downloaded.count) downloaded \(platformName) file(s) - count now \(self.sharedMedia.count)")
                    }
                    completion()
                case .failure(let error):
                    shareLog("ERROR: \(platformName) download failed - \(error.localizedDescription)")
                    self.appendLiteralShare(item: item, type: type)
                    completion()
                }
            }
            return
        }
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

        if pendingPlatformType == nil {
            if let inferred = inferredPlatformType {
                pendingPlatformType = inferred
            } else if type == .url {
                pendingPlatformType = "web"
            }
        }
    }

    private func isInstagramShareCandidate(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.contains("instagram.com/p/") || trimmed.contains("instagram.com/reel/")
    }

    private func isTikTokShareCandidate(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Match various TikTok URL formats:
        // - tiktok.com/@ (profile or video)
        // - tiktok.com/video/ (direct video)
        // - tiktok.com/t/ (short links)
        // - vm.tiktok.com/ (short redirect URLs)
        // - vt.tiktok.com/ (another short format)
        if trimmed.contains("vm.tiktok.com/") || trimmed.contains("vt.tiktok.com/") {
            return true
        }
        return trimmed.contains("tiktok.com/") && (trimmed.contains("/video/") || trimmed.contains("/@") || trimmed.contains("/t/"))
    }

    private func isPinterestShareCandidate(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.contains("pinterest.com/pin/") || trimmed.contains("pin.it/")
    }

    private func isYouTubeShareCandidate(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmed.contains("youtube.com") && !trimmed.contains("youtu.be") {
            return false
        }
        // Must have video ID indicator
        return trimmed.contains("/watch") || trimmed.contains("/shorts/") ||
               trimmed.contains("youtu.be/") || trimmed.contains("/v/")
    }

    private func isGoogleImageShareCandidate(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hasGoogleHost = trimmed.contains("://www.google.") ||
                           trimmed.contains("://google.") ||
                           trimmed.contains("www.google.") ||
                           trimmed.contains("google.")
        if !hasGoogleHost { return false }
        let hasImgresPath = trimmed.contains("/imgres") || trimmed.contains("/search")
        if !hasImgresPath { return false }
        return trimmed.contains("imgurl=")
    }

    private func isDownloadableUrlCandidate(_ value: String) -> Bool {
        return isInstagramShareCandidate(value) ||
               isTikTokShareCandidate(value) ||
               isPinterestShareCandidate(value) ||
               isYouTubeShareCandidate(value) ||
               isGoogleImageShareCandidate(value)
    }

    // Legacy function for backward compatibility
    private func isSocialMediaShareCandidate(_ value: String) -> Bool {
        return isInstagramShareCandidate(value) || isTikTokShareCandidate(value)
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

    // MARK: - TikTok Scraping

    private func downloadTikTokMedia(
        from urlString: String,
        completion: @escaping (Result<[SharedMediaFile], Error>) -> Void
    ) {
        // Free path: try TikTok oEmbed first (no ScrapingBee credits).
        fetchTikTokOEmbedThumbnail(urlString: urlString) { [weak self] thumbUrl in
            guard let self = self else { return }

            if let thumbUrl = thumbUrl {
                self.downloadFirstValidImage(
                    from: [thumbUrl],
                    platform: "tiktok",
                    session: URLSession.shared,
                    cropToAspect: 9.0 / 16.0,
                    completion: completion
                )
                return
            }

            // Fallback: fetch via Jina proxy and parse HTML.
            self.fetchTikTokViaJina(urlString: urlString) { imageUrls in
                guard !imageUrls.isEmpty else {
                    completion(.failure(self.makeTikTokError("No TikTok thumbnail found")))
                    return
                }
                self.downloadFirstValidImage(
                    from: Array(imageUrls.prefix(5)),
                    platform: "tiktok",
                    session: URLSession.shared,
                    cropToAspect: 9.0 / 16.0,
                    completion: completion
                )
            }
        }
    }

    private func fetchTikTokOEmbedThumbnail(
        urlString: String,
        completion: @escaping (String?) -> Void
    ) {
        resolveTikTokRedirect(urlString: urlString) { [weak self] resolvedUrl in
            guard let self = self else { return }

            let targetUrl = resolvedUrl ?? urlString

            guard let encoded = targetUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let oembedUrl = URL(string: "https://www.tiktok.com/oembed?url=\(encoded)") else {
                completion(nil)
                return
            }

            var request = URLRequest(url: oembedUrl)
            request.timeoutInterval = 10.0
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
                forHTTPHeaderField: "User-Agent"
            )

            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }

                guard error == nil,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(nil)
                    return
                }

                if let thumb = (json["thumbnail_url"] as? String)
                    ?? (json["thumbnailUrl"] as? String)
                    ?? (json["thumbnailURL"] as? String),
                   !thumb.isEmpty {
                    shareLog("TikTok oEmbed thumbnail: \(thumb.prefix(80))...")
                    completion(thumb)
                    return
                }

                completion(nil)
            }
            task.resume()
        }
    }

    private func resolveTikTokRedirect(
        urlString: String,
        completion: @escaping (String?) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.httpMethod = "GET"

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                completion(nil)
                return
            }
            if let finalUrl = response?.url?.absoluteString, finalUrl != urlString {
                completion(finalUrl)
            } else {
                completion(nil)
            }
        }
        task.resume()
    }

    private func fetchInstagramViaJina(
        urlString: String,
        completion: @escaping ([String]) -> Void
    ) {
        let rfc3986 = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;=")
        guard let encodedTarget = urlString.addingPercentEncoding(withAllowedCharacters: rfc3986) else {
            completion([])
            return
        }
        let proxyString = "https://r.jina.ai/\(encodedTarget)"
        guard let proxyUrl = URL(string: proxyString) else {
            completion([])
            return
        }

        var request = URLRequest(url: proxyUrl)
        request.timeoutInterval = 12.0
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data,
                  let html = String(data: data, encoding: .utf8) else {
                completion([])
                return
            }

            let imageUrls = self.extractInstagramImageUrls(from: html)
            completion(imageUrls)
        }
        task.resume()
    }

    private func fetchTikTokViaJina(
        urlString: String,
        completion: @escaping ([String]) -> Void
    ) {
        resolveTikTokRedirect(urlString: urlString) { resolvedUrl in
            let targetUrl = resolvedUrl ?? urlString
            let rfc3986 = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;=")
            guard let encodedTarget = targetUrl.addingPercentEncoding(withAllowedCharacters: rfc3986) else {
                completion([])
                return
            }
            let proxyString = "https://r.jina.ai/\(encodedTarget)"
            guard let proxyUrl = URL(string: proxyString) else {
                completion([])
                return
            }

            var request = URLRequest(url: proxyUrl)
            request.timeoutInterval = 12.0
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
                forHTTPHeaderField: "User-Agent"
            )

            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                guard error == nil,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let data = data,
                      let html = String(data: data, encoding: .utf8) else {
                    completion([])
                    return
                }

                let imageUrls = self.extractTikTokImageUrls(from: html)
                completion(imageUrls)
            }
            task.resume()
        }
    }



    private func isTikTokBlockedPage(_ html: String) -> Bool {
        let lowered = html.lowercased()
        if lowered.contains("captcha") || lowered.contains("verify") || lowered.contains("login") && lowered.contains("tiktok") {
            return true
        }
        if lowered.contains("please enable javascript") || lowered.contains("robot check") {
            return true
        }
        if let titleRange = html.range(of: "<title>([^<]*)</title>", options: .regularExpression),
           html[titleRange].lowercased().contains("log in | tiktok") {
            return true
        }
        return false
    }

    private func extractTikTokImageUrls(from html: String) -> [String] {
        var priorityResults: [String] = []
        var fallbackResults: [String] = []

        func appendUnique(_ url: String, to array: inout [String]) {
            if !array.contains(url) {
                array.append(url)
            }
        }

        func cleaned(_ candidate: String) -> String {
            return candidate.replacingOccurrences(of: "&amp;", with: "&")
        }

        func isLowValue(_ url: String) -> Bool {
            return url.contains("avt-") || url.contains("100x100") || url.contains("cropcenter") || url.contains("music")
        }

        // Meta tags: og:image / twitter:image often hold the best thumbnail
        let metaPattern = "<meta[^>]+property=\"(?:og:image|twitter:image)\"[^>]+content=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: metaPattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, options: [], range: nsrange) { match, _, _ in
                guard let match = match,
                      match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else { return }
                let candidate = cleaned(String(html[range]))
                if !isLowValue(candidate) {
                    appendUnique(candidate, to: &priorityResults)
                }
            }
        }

        // JSON cover fields (present in TikTok initial data)
        let coverPattern = "\"cover\"\\s*:\\s*\"(https://[^\"]*tiktokcdn[^\"]*)\""
        if let regex = try? NSRegularExpression(pattern: coverPattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, options: [], range: nsrange) { match, _, _ in
                guard let match = match,
                      match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else { return }
                let candidate = cleaned(String(html[range]))
                if !isLowValue(candidate) {
                    appendUnique(candidate, to: &priorityResults)
                }
            }
        }

        // Pattern 1: Look for high-quality video thumbnails from tiktokcdn.com
        // These are in img src with tplv-tiktokx-origin.image (highest priority)
        let originPattern = "src=\"(https://[^\"]*tiktokcdn[^\"]*tplv-tiktokx-origin\\.image[^\"]*)\""
        if let regex = try? NSRegularExpression(pattern: originPattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, options: [], range: nsrange) { match, _, _ in
                guard let match = match,
                      match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else { return }
                let candidate = cleaned(String(html[range]))
                // Skip avatars and small images
                if isLowValue(candidate) {
                    return
                }
                appendUnique(candidate, to: &priorityResults)
            }
        }

        // If we found high-quality thumbnails, return only those
        if !priorityResults.isEmpty {
            shareLog("Extracted \(priorityResults.count) high-quality TikTok image URL(s)")
            return priorityResults
        }

        // Pattern 2: Look for poster images in video tags (fallback)
        let posterPattern = "poster=\"(https://[^\"]*tiktokcdn[^\"]*)\""
        if let regex = try? NSRegularExpression(pattern: posterPattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, options: [], range: nsrange) { match, _, _ in
                guard let match = match,
                      match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else { return }
                let candidate = cleaned(String(html[range]))
                if !isLowValue(candidate) {
                    appendUnique(candidate, to: &fallbackResults)
                }
            }
        }

        // Pattern 3: Any img src from tiktokcdn that looks like a thumbnail
        let imgPattern = "<img[^>]+src=\"(https://[^\"]*tiktokcdn[^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: imgPattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, options: [], range: nsrange) { match, _, _ in
                guard let match = match,
                      match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else { return }
                let candidate = cleaned(String(html[range]))
                if !isLowValue(candidate) {
                    appendUnique(candidate, to: &fallbackResults)
                }
            }
        }

        // Pattern 4: Any tiktokcdn image URL in body as a last resort (supports photo-mode without extension)
        let loosePattern = "https://\\S*tiktokcdn\\S*"
        if let regex = try? NSRegularExpression(pattern: loosePattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, options: [], range: nsrange) { match, _, _ in
                guard let match = match,
                      match.numberOfRanges > 0,
                      let range = Range(match.range(at: 0), in: html) else { return }
                let candidate = cleaned(String(html[range]))
                if !isLowValue(candidate) {
                    appendUnique(candidate, to: &fallbackResults)
                }
            }
        }

        // Pattern 5: Markdown image syntax ![](url) capturing tiktokcdn URLs specifically
        let markdownImagePattern = "!\\[[^\\]]*\\]\\((https?://[^)]+tiktokcdn[^)]+)\\)"
        if let regex = try? NSRegularExpression(pattern: markdownImagePattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, options: [], range: nsrange) { match, _, _ in
                guard let match = match,
                      match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else { return }
                let candidate = cleaned(String(html[range]))
                if !isLowValue(candidate) {
                    appendUnique(candidate, to: &fallbackResults)
                }
            }
        }

        shareLog("Extracted \(fallbackResults.count) TikTok image URL(s)")
        return fallbackResults
    }

    private func makeTikTokError(_ message: String, code: Int = -1) -> NSError {
        return NSError(
            domain: "TikTokScraper",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    // MARK: - Pinterest Scraping

    private func downloadPinterestMedia(
        from urlString: String,
        completion: @escaping (Result<[SharedMediaFile], Error>) -> Void
    ) {
        guard let apiKey = scrapingBeeApiKey(), !apiKey.isEmpty else {
            shareLog("ScrapingBee API key missing - cannot download Pinterest image")
            completion(.failure(makeDownloadError("Pinterest", "ScrapingBee API key not configured")))
            return
        }

        guard var components = URLComponents(string: "https://app.scrapingbee.com/api/v1/") else {
            completion(.failure(makeDownloadError("Pinterest", "Invalid ScrapingBee URL")))
            return
        }

        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "url", value: urlString),
            URLQueryItem(name: "render_js", value: "true"),
            URLQueryItem(name: "wait", value: "2000")
        ]

        guard let requestURL = components.url else {
            completion(.failure(makeDownloadError("Pinterest", "Failed to build request URL")))
            return
        }

        shareLog("Fetching Pinterest HTML via ScrapingBee for \(urlString)")

        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 25.0

        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                session.invalidateAndCancel()
                DispatchQueue.main.async {
                    completion(.failure(self.makeDownloadError("Pinterest", "Network error: \(error.localizedDescription)")))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let data = data, let html = String(data: data, encoding: .utf8) else {
                session.invalidateAndCancel()
                DispatchQueue.main.async {
                    completion(.failure(self.makeDownloadError("Pinterest", "Failed to fetch page")))
                }
                return
            }

            let imageUrls = self.extractPinterestImageUrls(from: html)
            if imageUrls.isEmpty {
                session.invalidateAndCancel()
                DispatchQueue.main.async {
                    completion(.failure(self.makeDownloadError("Pinterest", "No images found")))
                }
                return
            }

            self.downloadFirstValidImage(from: imageUrls, platform: "pinterest", session: session, completion: completion)
        }
        task.resume()
    }

    private func extractPinterestImageUrls(from html: String) -> [String] {
        var results: [String] = []
        var seenUrls = Set<String>()

        // Pattern 1: og:image meta tag (usually highest quality)
        let ogImagePattern = "<meta[^>]+property=\"og:image\"[^>]+content=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: ogImagePattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            if let match = regex.firstMatch(in: html, options: [], range: nsrange),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: html) {
                let url = String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
                if !seenUrls.contains(url) {
                    seenUrls.insert(url)
                    results.append(url)
                }
            }
        }

        // Pattern 2: originals pinimg (highest resolution)
        let originalsPattern = "src=\"(https://i\\.pinimg\\.com/originals/[^\"]+\\.(?:jpg|jpeg|png|webp))\""
        if let regex = try? NSRegularExpression(pattern: originalsPattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, options: [], range: nsrange) { match, _, _ in
                guard let match = match, match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else { return }
                let url = String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
                if !seenUrls.contains(url) {
                    seenUrls.insert(url)
                    results.append(url)
                }
            }
        }

        // Pattern 3: 564x pinimg (medium-high resolution)
        let mediumPattern = "src=\"(https://i\\.pinimg\\.com/564x/[^\"]+\\.(?:jpg|jpeg|png|webp))\""
        if let regex = try? NSRegularExpression(pattern: mediumPattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, options: [], range: nsrange) { match, _, _ in
                guard let match = match, match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else { return }
                let url = String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
                if !seenUrls.contains(url) {
                    seenUrls.insert(url)
                    results.append(url)
                }
            }
        }

        // Pattern 4: Any pinimg URL as fallback
        let anyPinimgPattern = "src=\"(https://i\\.pinimg\\.com/[^\"]+\\.(?:jpg|jpeg|png|webp))\""
        if let regex = try? NSRegularExpression(pattern: anyPinimgPattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, options: [], range: nsrange) { match, _, _ in
                guard let match = match, match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else { return }
                let url = String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
                if !seenUrls.contains(url) {
                    seenUrls.insert(url)
                    results.append(url)
                }
            }
        }

        shareLog("Extracted \(results.count) Pinterest image URL(s)")
        return results
    }

    // MARK: - YouTube Thumbnail Download

    private func downloadYouTubeMedia(
        from urlString: String,
        completion: @escaping (Result<[SharedMediaFile], Error>) -> Void
    ) {
        let isShortsLink = urlString.lowercased().contains("/shorts")
        guard let videoId = extractYouTubeVideoId(from: urlString) else {
            shareLog("Unable to extract YouTube video ID from \(urlString)")
            completion(.failure(makeDownloadError("YouTube", "Could not extract video ID")))
            return
        }

        let thumbnailUrls = buildYouTubeThumbnailCandidates(videoId: videoId)
        shareLog("Trying \(thumbnailUrls.count) YouTube thumbnail candidates for video \(videoId)")

        downloadFirstValidImage(
            from: thumbnailUrls,
            platform: "youtube",
            session: URLSession.shared,
            cropToAspect: isShortsLink ? (9.0 / 16.0) : nil,
            completion: completion
        )
    }

    private func extractYouTubeVideoId(from urlString: String) -> String? {
        // Pattern 1: youtu.be/VIDEO_ID
        if urlString.contains("youtu.be/") {
            if let range = urlString.range(of: "youtu.be/") {
                var videoId = String(urlString[range.upperBound...])
                // Remove query parameters
                if let queryIndex = videoId.firstIndex(of: "?") {
                    videoId = String(videoId[..<queryIndex])
                }
                return videoId.isEmpty ? nil : videoId
            }
        }

        // Pattern 2: youtube.com/watch?v=VIDEO_ID
        if let url = URL(string: urlString),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                if item.name == "v", let value = item.value, !value.isEmpty {
                    return value
                }
            }
        }

        // Pattern 3: youtube.com/shorts/VIDEO_ID or youtube.com/v/VIDEO_ID
        let patterns = ["/shorts/", "/v/", "/embed/"]
        for pattern in patterns {
            if let range = urlString.range(of: pattern) {
                var videoId = String(urlString[range.upperBound...])
                // Remove trailing path or query
                if let slashIndex = videoId.firstIndex(of: "/") {
                    videoId = String(videoId[..<slashIndex])
                }
                if let queryIndex = videoId.firstIndex(of: "?") {
                    videoId = String(videoId[..<queryIndex])
                }
                if !videoId.isEmpty {
                    return videoId
                }
            }
        }

        return nil
    }

    private func buildYouTubeThumbnailCandidates(videoId: String) -> [String] {
        let hosts = [
            "https://i.ytimg.com/vi",
            "https://img.youtube.com/vi"
        ]

        let variants = [
            "maxresdefault.jpg",
            "maxres1.jpg",
            "maxres2.jpg",
            "maxres3.jpg",
            "sddefault.jpg",
            "hq720.jpg",
            "hqdefault.jpg",
            "mqdefault.jpg"
        ]

        var candidates: [String] = []
        for host in hosts {
            for variant in variants {
                candidates.append("\(host)/\(videoId)/\(variant)")
            }
        }

        // Live and WebP fallbacks
        candidates.append("https://i.ytimg.com/vi/\(videoId)/maxresdefault_live.jpg")
        candidates.append("https://i.ytimg.com/vi_webp/\(videoId)/maxresdefault.webp")
        candidates.append("https://i.ytimg.com/vi_webp/\(videoId)/hqdefault.webp")

        return candidates
    }

    // MARK: - Google Image Download

    private func downloadGoogleImageMedia(
        from urlString: String,
        completion: @escaping (Result<[SharedMediaFile], Error>) -> Void
    ) {
        guard let imageUrl = extractGoogleImageUrl(from: urlString) else {
            shareLog("Could not extract imgurl from Google link")
            completion(.failure(makeDownloadError("GoogleImage", "Could not parse image URL")))
            return
        }

        let cleanedUrl = imageUrl.hasPrefix("http") ? imageUrl : "https://\(imageUrl)"
        shareLog("Downloading Google Image directly: \(cleanedUrl.prefix(80))...")

        downloadFirstValidImage(from: [cleanedUrl], platform: "google_image", session: URLSession.shared, completion: completion)
    }

    private func extractGoogleImageUrl(from urlString: String) -> String? {
        let lowercased = urlString.lowercased()
        guard let index = lowercased.range(of: "imgurl=") else { return nil }

        let startIndex = urlString.index(index.upperBound, offsetBy: 0, limitedBy: urlString.endIndex) ?? urlString.endIndex
        let raw = String(urlString[startIndex...])

        let endIndex = raw.firstIndex(of: "&") ?? raw.endIndex
        let candidate = String(raw[..<endIndex])

        // URL decode
        return candidate.removingPercentEncoding ?? candidate
    }

    // MARK: - Generic Link Scraping

    private func downloadGenericLinkMedia(
        from urlString: String,
        completion: @escaping (Result<[SharedMediaFile], Error>) -> Void
    ) {
        // Free path: quick HTML fetch to grab og/twitter/img
        quickGenericImageScrape(urlString: urlString) { [weak self] quickImages in
            guard let self = self else { return }

            if !quickImages.isEmpty {
                self.downloadFirstValidImage(
                    from: Array(quickImages.prefix(5)),
                    platform: "generic",
                    session: URLSession.shared,
                    completion: completion
                )
                return
            }

            // No images found in quick scrape; return failure without ScrapingBee
            completion(.failure(self.makeDownloadError("GenericLink", "No images found on page")))
        }
    }

    private func quickGenericImageScrape(
        urlString: String,
        completion: @escaping ([String]) -> Void
    ) {
        // Google imgres: extract imgurl directly (creditless)
        if let imgUrl = extractGoogleImgUrl(from: urlString) {
            completion([imgUrl])
            return
        }

        // Direct image URL: return immediately
        if looksLikeImageUrl(urlString) {
            completion([urlString])
            return
        }

        guard let url = URL(string: urlString) else {
            completion([])
            return
        }

        // Google Images thumbnail/shared URLs (encrypted-tbn* or imgres without imgurl) - treat as direct images
        if let host = url.host?.lowercased(), host.contains("gstatic.com"), host.contains("tbn") {
            if let preferred = extractPreferredImageParam(from: urlString) {
                completion([preferred])
                return
            }
            completion([urlString])
            return
        }
        if let host = url.host?.lowercased(),
           host.contains("google."),
           (url.path.lowercased().contains("/imgres") || url.query?.contains("tbn:") == true) {
            if let preferred = extractPreferredImageParam(from: urlString) {
                completion([preferred])
                return
            }
            completion([urlString])
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data,
                  let html = String(data: data, encoding: .utf8) else {
                completion([])
                return
            }

            let images = self.extractGenericImageUrls(from: html, baseUrl: url)
            if let best = images.first {
                completion([best])
            } else {
                completion([])
            }
        }.resume()
    }

    private func extractGenericImageUrls(from html: String, baseUrl: URL) -> [String] {
        var results: [String] = []

        func resolve(_ raw: String?) -> String? {
            guard let raw = raw, !raw.isEmpty, !raw.hasPrefix("data:") else { return nil }
            let lower = raw.lowercased()
            if lower.contains("favicon") ||
                lower.contains("googlelogo") ||
                lower.contains("gstatic.com/favicon") ||
                lower.contains("tbn:") ||
                lower.contains("tbn0.gstatic.com") {
                return nil
            }
            return baseUrl.resolve(raw)
        }

        let patterns = [
            "<meta[^>]+property=\"og:image\"[^>]+content=\"([^\"]+)\"",
            "<meta[^>]+name=\"twitter:image\"[^>]+content=\"([^\"]+)\"",
        ]

        for pat in patterns {
            if let regex = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) {
                let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
                if let match = regex.firstMatch(in: html, options: [], range: nsrange),
                   match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: html),
                   let resolved = resolve(String(html[range])),
                   !results.contains(resolved) {
                    results.append(resolved)
                }
            }
        }

        let imgPattern = "<img[^>]+src=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: imgPattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            var count = 0
            regex.enumerateMatches(in: html, options: [], range: nsrange) { match, _, stop in
                guard count < 5,
                      let match = match,
                      match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html),
                      let resolved = resolve(String(html[range])),
                      !results.contains(resolved) else { return }
                results.append(resolved)
                count += 1
                if count >= 5 { stop.pointee = true }
            }
        }

        return results
    }

    private func looksLikeImageUrl(_ urlString: String) -> Bool {
        let lower = urlString.lowercased()
        return lower.hasSuffix(".jpg") ||
            lower.hasSuffix(".jpeg") ||
            lower.hasSuffix(".png") ||
            lower.hasSuffix(".webp") ||
            lower.contains(".jpg?") ||
            lower.contains(".jpeg?") ||
            lower.contains(".png?") ||
            lower.contains(".webp?") ||
            lower.contains("tbn:") // Google Images thumbnails
    }

    private func extractGoogleImgUrl(from urlString: String) -> String? {
        let lower = urlString.lowercased()
        guard lower.contains("google.") && lower.contains("imgurl=") else { return nil }

        return extractPreferredImageParam(from: urlString, keys: ["imgurl"])
    }

    private func extractPreferredImageParam(from urlString: String, keys: [String] = ["imgurl", "mediaurl", "url", "image_url"]) -> String? {
        guard let components = URLComponents(string: urlString),
              let items = components.queryItems else { return nil }
        for key in keys {
            if let value = items.first(where: { $0.name.lowercased() == key.lowercased() })?.value,
               !value.isEmpty {
                return value.removingPercentEncoding ?? value
            }
        }
        return nil
    }

    // MARK: - Common Download Helper

    private func downloadFirstValidImage(
        from urls: [String],
        platform: String,
        session: URLSession,
        cropToAspect: CGFloat? = nil,
        completion: @escaping (Result<[SharedMediaFile], Error>) -> Void
    ) {
        guard !urls.isEmpty else {
            DispatchQueue.main.async {
                completion(.failure(self.makeDownloadError(platform, "No image URLs to try")))
            }
            return
        }

        var urlsToTry = urls
        let firstUrl = urlsToTry.removeFirst()

        guard let url = URL(string: firstUrl) else {
            // Try next URL
            downloadFirstValidImage(from: urlsToTry, platform: platform, session: session, cropToAspect: cropToAspect, completion: completion)
            return
        }

        shareLog("Trying to download \(platform) image: \(firstUrl.prefix(80))...")

        let task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            // Check if download succeeded
            if let error = error {
                shareLog("Failed to download from \(firstUrl.prefix(50))...: \(error.localizedDescription)")
                // Try next URL
                self.downloadFirstValidImage(from: urlsToTry, platform: platform, session: session, cropToAspect: cropToAspect, completion: completion)
                return
            }

            guard let data = data, !data.isEmpty,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                // Try next URL
                self.downloadFirstValidImage(from: urlsToTry, platform: platform, session: session, cropToAspect: cropToAspect, completion: completion)
                return
            }

            var dataToSave = data
            if let targetAspect = cropToAspect,
               let image = UIImage(data: data),
               image.size.width > 0,
               image.size.height > 0 {
                let currentAspect = image.size.width / image.size.height
                if abs(currentAspect - targetAspect) > 0.01 {
                    var cropRect = CGRect(origin: .zero, size: image.size)
                    if currentAspect > targetAspect {
                        let targetWidth = image.size.height * targetAspect
                        let originX = max(0, (image.size.width - targetWidth) / 2)
                        cropRect = CGRect(x: originX, y: 0, width: targetWidth, height: image.size.height)
                    } else {
                        let targetHeight = image.size.width / targetAspect
                        let originY = max(0, (image.size.height - targetHeight) / 2)
                        cropRect = CGRect(x: 0, y: originY, width: image.size.width, height: targetHeight)
                    }

                    if let cgImage = image.cgImage?.cropping(to: cropRect.integral) {
                        let cropped = UIImage(cgImage: cgImage)
                        if let croppedData = cropped.jpegData(compressionQuality: 0.95) {
                            dataToSave = croppedData
                            shareLog("Cropped \(platform) image to aspect \(String(format: "%.2f", targetAspect)) -> \(Int(cropRect.width))x\(Int(cropRect.height))")
                        }
                    }
                }
            }

            // Save to shared container
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.appGroupId) else {
                DispatchQueue.main.async {
                    completion(.failure(self.makeDownloadError(platform, "Cannot access shared container")))
                }
                return
            }

            let timestamp = Int(Date().timeIntervalSince1970 * 1000)
            let fileName = "\(platform)_image_\(timestamp).jpg"
            let fileURL = containerURL.appendingPathComponent(fileName)

            do {
                try dataToSave.write(to: fileURL, options: .atomic)
                shareLog("Saved \(platform) image to \(fileName) (\(dataToSave.count) bytes)")

                let sharedFile = SharedMediaFile(
                    path: fileURL.absoluteString,
                    thumbnail: nil,
                    duration: nil,
                    type: .image
                )

                DispatchQueue.main.async {
                    completion(.success([sharedFile]))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(self.makeDownloadError(platform, "Failed to save image: \(error.localizedDescription)")))
                }
            }
        }
        task.resume()
    }

    private func makeDownloadError(_ platform: String, _ message: String, code: Int = -1) -> NSError {
        return NSError(
            domain: "\(platform)Scraper",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    // MARK: - Platform Helper Functions

    private func getDownloadFunction(for platformType: String?) -> (String, @escaping (Result<[SharedMediaFile], Error>) -> Void) -> Void {
        switch platformType {
        case "instagram":
            return downloadInstagramMedia
        case "tiktok":
            return downloadTikTokMedia
        case "pinterest":
            return downloadPinterestMedia
        case "youtube":
            return downloadYouTubeMedia
        case "google_image":
            return downloadGoogleImageMedia
        case "generic":
            return downloadGenericLinkMedia
        default:
            // Fallback to generic
            return downloadGenericLinkMedia
        }
    }

    private func getPlatformDisplayName(_ platformType: String?) -> String {
        switch platformType {
        case "instagram":
            return "Instagram"
        case "tiktok":
            return "TikTok"
        case "pinterest":
            return "Pinterest"
        case "youtube":
            return "YouTube"
        case "google_image":
            return "Google Image"
        case "generic":
            return "Generic Link"
        default:
            return "Unknown"
        }
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
    private func checkCacheForInstagram(url: String, completion: @escaping (Bool) -> Void) {
        shareLog("Checking cache for Instagram URL: \(url)")

        guard let serverBaseUrl = getServerBaseUrl() else {
            shareLog("ERROR: Could not determine server base URL for cache check")
            completion(false)
            return
        }

        // Construct cache check endpoint with query parameter
        guard var components = URLComponents(string: serverBaseUrl + "/api/v1/cache/check") else {
            shareLog("ERROR: Failed to create URL components for cache check")
            completion(false)
            return
        }

        components.queryItems = [URLQueryItem(name: "source_url", value: url)]

        guard let checkUrl = components.url else {
            shareLog("ERROR: Failed to build cache check URL")
            completion(false)
            return
        }

        var request = URLRequest(url: checkUrl)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0

        shareLog("Sending cache check request to: \(checkUrl)")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                completion(false)
                return
            }

            if let error = error {
                shareLog("Cache check network error: \(error.localizedDescription)")
                completion(false)
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            shareLog("Cache check response - status code: \(statusCode)")

            guard statusCode == 200, let data = data else {
                shareLog("Cache check failed or returned non-200 status")
                completion(false)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let cached = json["cached"] as? Bool ?? false

                    if cached {
                        shareLog("Cache HIT - processing cached results")

                        // Extract cached data
                        let totalResults = json["total_results"] as? Int ?? 0
                        let cacheId = json["cache_id"] as? String
                        let detectedGarmentsArray = json["detected_garments"] as? [[String: Any]] ?? []
                        let searchResultsArray = json["search_results"] as? [[String: Any]] ?? []

                        shareLog("Cache data: \(totalResults) results, cache_id: \(cacheId ?? "nil")")

                        // Convert JSON arrays to DetectionResultItem
                        var results: [DetectionResultItem] = []
                        for resultDict in searchResultsArray {
                            if let jsonData = try? JSONSerialization.data(withJSONObject: resultDict),
                               let item = try? JSONDecoder().decode(DetectionResultItem.self, from: jsonData) {
                                results.append(item)
                            }
                        }

                        shareLog("Parsed \(results.count) cached results")

                        // Store cache_id for favorites functionality
                        self.currentImageCacheId = cacheId

                        // Note: We don't have a search_id from cache check endpoint
                        // search_id is only created when user actually analyzes (not when checking cache)
                        self.currentSearchId = nil

                        // Update UI with cached results
                        DispatchQueue.main.async {
                            self.updateProgress(1.0, status: "Found results")
                            self.stopSmoothProgress()

                            let sanitized = self.sanitize(results: results)
                            self.detectionResults = sanitized
                            self.isShowingDetectionResults = true

                            // Haptic feedback for successful cache hit
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()

                            shareLog("Displaying \(self.detectionResults.count) cached results")
                            self.showDetectionResults()
                        }

                        completion(true)
                    } else {
                        shareLog("Cache MISS - no cached results available")
                        completion(false)
                    }
                }
            } catch {
                shareLog("ERROR: Failed to parse cache check response: \(error.localizedDescription)")
                completion(false)
            }
        }

        task.resume()
    }

    private func runDetectionAnalysis(imageUrl: String?, imageBase64: String) {
        let urlForLog = imageUrl ?? "<nil>"
        shareLog("START runDetectionAnalysis - imageUrl: \(urlForLog), base64 length: \(imageBase64.count)")

        guard let serverBaseUrl = getServerBaseUrl() else {
            shareLog("ERROR: Could not determine server base URL")
            handleDetectionFailure(reason: "Detection setup is incomplete. Please open Snaplook to finish configuring analysis.")
            return
        }

        // Use new caching endpoint
        let analyzeEndpoint = serverBaseUrl + "/api/v1/analyze"
        shareLog("Detection endpoint: \(analyzeEndpoint)")
        targetProgress = max(targetProgress, detectTargetCap)

        // Ensure status rotation is running (in case we came from a path that didn't start it)
        if currentStatusMessages.isEmpty {
            let searchMessages = [
                "Analyzing look...",
                "Finding similar items...",
                "Checking retailers...",
                "Finalizing results..."
            ]
            startStatusRotation(messages: searchMessages, interval: 2.0, stopAtLast: false)
        }

        // Determine search type based on source
        var searchType = "unknown"
        var sourceUrl: String? = nil
        var sourceUsername: String? = nil

        if let pendingUrl = pendingInstagramUrl {
            sourceUrl = pendingUrl
            let lowercased = pendingUrl.lowercased()

            // Detect platform from URL
            if lowercased.contains("instagram.com") {
                searchType = "instagram"
                sourceUsername = extractInstagramUsername(from: pendingUrl)
            } else if lowercased.contains("tiktok.com") {
                searchType = "tiktok"
            } else if lowercased.contains("pinterest.com") || lowercased.contains("pin.it") {
                searchType = "pinterest"
            } else if lowercased.contains("twitter.com") || lowercased.contains("x.com") {
                searchType = "twitter"
            } else if lowercased.contains("facebook.com") || lowercased.contains("fb.com") {
                searchType = "facebook"
            } else {
                // Generic web source
                searchType = "web"
            }
        } else if imageUrl != nil {
            searchType = "photos"
        } else {
            searchType = "camera"
        }

        var requestBody: [String: Any] = [
            "user_id": getUserId(),
            "image_base64": imageBase64,
            "search_type": searchType,
            "country": "NO",
            "language": "nb"
        ]

        if let imageUrl = imageUrl, !imageUrl.isEmpty {
            requestBody["image_url"] = imageUrl
        }

        if let sourceUrl = sourceUrl {
            requestBody["source_url"] = sourceUrl
        }

        if let sourceUsername = sourceUsername {
            requestBody["source_username"] = sourceUsername
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            shareLog("ERROR: Failed to serialize detection request JSON")
            handleDetectionFailure(reason: "Could not prepare the analysis request. Please try sharing again.")
            return
        }

        shareLog("Request body size: \(jsonData.count) bytes")

        guard let url = URL(string: analyzeEndpoint) else {
            shareLog("ERROR: Invalid detection endpoint URL: \(analyzeEndpoint)")
            handleDetectionFailure(reason: "The detection service URL looks invalid. Check your configuration in Snaplook.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 90.0  // Increased from 30s to 90s for multi-garment detection + SerpAPI searches

        shareLog("Sending detection API request to: \(analyzeEndpoint)")

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

                    // Store search_id and image_cache_id for favorites/save functionality
                    self.currentSearchId = detectionResponse.search_id
                    self.currentImageCacheId = detectionResponse.image_cache_id
                    if let searchId = detectionResponse.search_id {
                        shareLog("Stored search_id: \(searchId)")
                    }
                    if let cached = detectionResponse.cached {
                        shareLog("Cache status: \(cached ? "HIT" : "MISS")")
                    }

                    self.updateProgress(1.0, status: "Analysis complete")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.stopSmoothProgress()
                        let serverResults = detectionResponse.results
                        let sanitized = self.sanitize(results: serverResults)
                        if sanitized.count != serverResults.count {
                            shareLog("Sanitized \(serverResults.count - sanitized.count) banned keyword results")
                        }
                        self.detectionResults = sanitized
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

        let base64Image = imageData.base64EncodedString()
        shareLog("Base64 encoded - length: \(base64Image.count) chars")

        let resolvedUrl = pendingImageUrl?.isEmpty == false ? pendingImageUrl : downloadedImageUrl
        downloadedImageUrl = resolvedUrl
        shareLog("Calling runDetectionAnalysis...")

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

    // Check which products are already favorited
    private func checkFavoriteStatus(completion: @escaping () -> Void) {
        guard let serverBaseUrl = getServerBaseUrl() else {
            shareLog("Cannot check favorites - no server URL")
            completion()
            return
        }

        let productIds = detectionResults.map { $0.id }
        guard !productIds.isEmpty else {
            completion()
            return
        }

        let userId = getUserId()
        let endpoint = serverBaseUrl + "/api/v1/users/\(userId)/favorites/check"

        guard let url = URL(string: endpoint) else {
            shareLog("Invalid favorites check URL")
            completion()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let jsonData = try? JSONSerialization.data(withJSONObject: productIds) else {
            shareLog("Failed to serialize product IDs")
            completion()
            return
        }

        request.httpBody = jsonData
        request.timeoutInterval = 10.0

        shareLog("Checking favorite status for \(productIds.count) products")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                completion()
                return
            }

            if let error = error {
                shareLog("Favorites check network error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion() }
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            shareLog("Favorites check response - status code: \(statusCode)")

            guard statusCode == 200, let data = data else {
                shareLog("Favorites check failed or returned non-200 status")
                DispatchQueue.main.async { completion() }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let favoritedIds = json["favorited_product_ids"] as? [String] {
                    shareLog("Found \(favoritedIds.count) already-favorited products")
                    DispatchQueue.main.async {
                        self.favoritedProductIds = Set(favoritedIds)
                        self.updateFavoriteMappings(for: favoritedIds)
                        completion()
                    }
                } else {
                    shareLog("Failed to parse favorites check response")
                    DispatchQueue.main.async { completion() }
                }
            } catch {
                shareLog("Error parsing favorites check: \(error.localizedDescription)")
                DispatchQueue.main.async { completion() }
            }
        }

        task.resume()
    }

    // Show UI when no results are found
    private func showNoResultsUI() {
        shareLog("Displaying no results UI")

        // Hide loading indicator and progress bar
        activityIndicator?.stopAnimating()
        activityIndicator?.isHidden = true
        statusLabel?.isHidden = true
        progressView?.isHidden = true

        guard let loadingView = loadingView else {
            shareLog("ERROR: loadingView is nil - cannot show no results UI")
            return
        }

        // Create container for no results message
        let noResultsContainer = UIView()
        noResultsContainer.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 48, weight: .light)
        iconImageView.image = UIImage(systemName: "magnifyingglass", withConfiguration: config)
        iconImageView.tintColor = UIColor.systemGray3
        iconImageView.contentMode = .scaleAspectFit

        // Title
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "No Results Found"
        titleLabel.font = UIFont(name: "PlusJakartaSans-SemiBold", size: 20)
            ?? .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "We couldn't find any matching products.\nTry a different image with clearer clothing items."
        subtitleLabel.font = UIFont(name: "PlusJakartaSans-Regular", size: 14)
            ?? .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        // Tip label
        let tipLabel = UILabel()
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        tipLabel.text = "Tip: Avoid cropping too tight around the garment for better results."
        tipLabel.font = UIFont(name: "PlusJakartaSans-Regular", size: 12)
            ?? .systemFont(ofSize: 12, weight: .regular)
        tipLabel.textColor = UIColor.secondaryLabel
        tipLabel.textAlignment = .center
        tipLabel.numberOfLines = 0

        // Add main content to container (without tip)
        noResultsContainer.addSubview(iconImageView)
        noResultsContainer.addSubview(titleLabel)
        noResultsContainer.addSubview(subtitleLabel)

        loadingView.addSubview(noResultsContainer)
        loadingView.addSubview(tipLabel)

        NSLayoutConstraint.activate([
            // Main content centered (same approach as choice buttons page)
            noResultsContainer.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            noResultsContainer.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor),
            noResultsContainer.leadingAnchor.constraint(equalTo: loadingView.leadingAnchor, constant: 32),
            noResultsContainer.trailingAnchor.constraint(equalTo: loadingView.trailingAnchor, constant: -32),

            iconImageView.topAnchor.constraint(equalTo: noResultsContainer.topAnchor),
            iconImageView.centerXAnchor.constraint(equalTo: noResultsContainer.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 64),
            iconImageView.heightAnchor.constraint(equalToConstant: 64),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: noResultsContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: noResultsContainer.trailingAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: noResultsContainer.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: noResultsContainer.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: noResultsContainer.bottomAnchor),

            // Tip at bottom (same approach as disclaimer on choice buttons page)
            tipLabel.leadingAnchor.constraint(equalTo: loadingView.leadingAnchor, constant: 32),
            tipLabel.trailingAnchor.constraint(equalTo: loadingView.trailingAnchor, constant: -32),
            tipLabel.bottomAnchor.constraint(equalTo: loadingView.safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    @objc private func openAppFromNoResults() {
        shareLog("Open app tapped from no results screen")
        openSnaplookApp()
    }

    private func openSnaplookApp() {
        // Provide light feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        loadIds()
        guard let url = URL(string: "\(kSchemePrefix)-\(hostAppBundleIdentifier):share") else {
            shareLog("ERROR: Failed to create app URL for openSnaplookApp")
            return
        }

        shareLog("Attempting to open Snaplook app with URL: \(url.absoluteString)")

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
            while responder != nil {
                if responder!.responds(to: #selector(UIApplication.openURL(_:))) {
                    responder!.perform(#selector(UIApplication.openURL(_:)), with: url)
                    break
                }
                responder = responder!.next
            }
        }
    }

    // Show detection results in table view
    private func showDetectionResults() {
        shareLog("=== showDetectionResults START ===")
        shareLog("detectionResults.count: \(detectionResults.count)")
        shareLog("loadingView exists: \(loadingView != nil)")
        shareLog("resultsTableView exists: \(resultsTableView != nil)")

        guard !detectionResults.isEmpty else {
            shareLog("No results found - showing empty state UI")
            showNoResultsUI()
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

        // Check which products are already favorited before showing UI
        checkFavoriteStatus {
            self.displayResultsUI()
        }
    }

    private func displayResultsUI() {

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

        // Create bottom bar with Share button
        let bottomBarContainer = UIView()
        bottomBarContainer.backgroundColor = .systemBackground
        bottomBarContainer.translatesAutoresizingMaskIntoConstraints = false

        // Separator line
        let separator = UIView()
        separator.backgroundColor = UIColor.systemGray5
        separator.translatesAutoresizingMaskIntoConstraints = false

        // Share button (primary style - previously Save button)
        let shareButton = UIButton(type: .system)
        shareButton.setTitle("Share", for: .normal)
        shareButton.titleLabel?.font = UIFont(name: "PlusJakartaSans-Bold", size: 16)
            ?? .systemFont(ofSize: 16, weight: .bold)
        shareButton.backgroundColor = UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0)
        shareButton.setTitleColor(.white, for: .normal)
        shareButton.layer.cornerRadius = 28
        shareButton.addTarget(self, action: #selector(shareResultsTapped), for: .touchUpInside)
        shareButton.translatesAutoresizingMaskIntoConstraints = false

        bottomBarContainer.addSubview(separator)
        bottomBarContainer.addSubview(shareButton)

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

            // Share button (full width)
            shareButton.topAnchor.constraint(equalTo: bottomBarContainer.topAnchor, constant: 16),
            shareButton.leadingAnchor.constraint(equalTo: bottomBarContainer.leadingAnchor, constant: 16),
            shareButton.trailingAnchor.constraint(equalTo: bottomBarContainer.trailingAnchor, constant: -16),
            shareButton.heightAnchor.constraint(equalToConstant: 56)
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
        let primaryRed = UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0)
        button.setTitle(CategoryGroup.all.displayName, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        button.layer.cornerRadius = 18
        button.clipsToBounds = true
        button.layer.borderWidth = 1
        button.layer.borderColor = primaryRed.cgColor
        button.backgroundColor = primaryRed
        button.setTitleColor(.white, for: .normal)
        button.isUserInteractionEnabled = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true

        stackView.addArrangedSubview(button)

        // Results count label on far right
        let resultsCountLabel = UILabel()
        resultsCountLabel.translatesAutoresizingMaskIntoConstraints = false
        resultsCountLabel.font = .systemFont(ofSize: 14, weight: .medium)
        resultsCountLabel.textColor = .secondaryLabel
        resultsCountLabel.textAlignment = .right
        let count = detectionResults.count
        resultsCountLabel.text = count == 1 ? "1 result" : "\(count) results"
        resultsCountLabel.tag = 1001 // Tag for updating later

        scrollView.addSubview(stackView)
        containerView.addSubview(scrollView)
        containerView.addSubview(resultsCountLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: resultsCountLabel.leadingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),

            resultsCountLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            resultsCountLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
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

    private func sanitize(results: [DetectionResultItem]) -> [DetectionResultItem] {
        return results.filter { isAllowed(result: $0) }
    }

    private func isAllowed(result: DetectionResultItem) -> Bool {
        let fields = [
            result.product_name,
            result.brand ?? "",
            result.description ?? "",
            result.purchase_url ?? ""
        ].joined(separator: " ")

        let range = NSRange(location: 0, length: (fields as NSString).length)
        for regex in bannedKeywordPatterns {
            if regex.firstMatch(in: fields, options: [], range: range) != nil {
                return false
            }
        }
        return true
    }

    @objc private func saveAllTapped() {
        shareLog("Save All button tapped - saving all results and redirecting")

        // End extended execution since we're wrapping up
        endExtendedExecution()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Call backend API to save search
        if let searchId = currentSearchId {
            saveSearchToBackend(searchId: searchId)
        } else {
            shareLog("WARNING: No search_id available - skipping backend save")
        }

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

    // Get server base URL from detection endpoint
    private func getServerBaseUrl() -> String? {
        guard let endpoint = detectorEndpoint() else {
            return nil
        }

        // Extract base URL from endpoint like "https://domain.com/detect-and-search"
        if let url = URL(string: endpoint),
           let scheme = url.scheme,
           let host = url.host {
            var baseUrl = "\(scheme)://\(host)"
            if let port = url.port {
                baseUrl += ":\(port)"
            }
            return baseUrl
        }

        return nil
    }

    // Backend API calls for favorites and save
    private func saveSearchToBackend(searchId: String) {
        guard let serverBaseUrl = getServerBaseUrl(),
              let serverUrl = URL(string: serverBaseUrl) else {
            shareLog("ERROR: Could not determine server URL from detection endpoint")
            return
        }

        let endpoint = serverUrl.appendingPathComponent("api/v1/searches/\(searchId)/save")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "user_id": getUserId(),
            "name": nil as Any?
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            shareLog("ERROR: Failed to serialize save search request: \(error.localizedDescription)")
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                shareLog("ERROR: Save search request failed: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                shareLog("Save search response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    shareLog("Search saved successfully")
                } else {
                    shareLog("Save search failed with status \(httpResponse.statusCode)")
                }
            }
        }

        task.resume()
    }

    private func addFavoriteToBackend(product: DetectionResultItem, completion: @escaping (Bool) -> Void) {
        guard let serverBaseUrl = getServerBaseUrl(),
              let serverUrl = URL(string: serverBaseUrl) else {
            shareLog("ERROR: Could not determine server URL from detection endpoint")
            completion(false)
            return
        }

        let endpoint = serverUrl.appendingPathComponent("api/v1/favorites")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let productData: [String: Any] = [
            "id": product.id,
            "product_id": product.id,  // Also include as product_id for backwards compatibility
            "product_name": product.product_name,
            "brand": product.brand ?? "",
            "price": product.priceValue ?? 0.0,
            "image_url": product.image_url,
            "purchase_url": product.purchase_url ?? "",
            "category": product.category
        ]

        let body: [String: Any] = [
            "user_id": getUserId(),
            "search_id": currentSearchId as Any?,
            "product": productData
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            shareLog("ERROR: Failed to serialize add favorite request: \(error.localizedDescription)")
            completion(false)
            return
        }

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            if let error = error {
                shareLog("ERROR: Add favorite request failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                shareLog("ERROR: Add favorite response missing HTTP status")
                DispatchQueue.main.async { completion(false) }
                return
            }

            shareLog("Add favorite response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            var favoriteId: String?
            var alreadyExisted = false

            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        favoriteId = json["favorite_id"] as? String
                        alreadyExisted = json["already_existed"] as? Bool ?? false
                    }
                } catch {
                    shareLog("ERROR: Unable to parse add favorite response: \(error.localizedDescription)")
                }
            } else {
                shareLog("WARNING: Add favorite response contained no body")
            }

            if let favoriteId = favoriteId {
                DispatchQueue.main.async {
                    self.favoriteIdByProductId[product.id] = favoriteId
                    shareLog("Add favorite success - favorite_id: \(favoriteId), already existed: \(alreadyExisted)")
                    completion(true)
                }
            } else {
                shareLog("WARNING: favorite_id missing after add favorite, attempting mapping refresh")
                self.updateFavoriteMappings(for: [product.id]) { _ in
                    completion(true)
                }
            }
        }

        task.resume()
    }

    private func removeFavoriteFromBackend(
        product: DetectionResultItem,
        completion: @escaping (Bool) -> Void
    ) {
        ensureFavoriteId(for: product.id) { [weak self] favoriteId in
            guard let self = self else {
                completion(false)
                return
            }

            guard let favoriteId = favoriteId else {
                shareLog("ERROR: Unable to resolve favorite_id for product \(product.id)")
                completion(false)
                return
            }

            guard let serverBaseUrl = self.getServerBaseUrl() else {
                shareLog("ERROR: Could not determine server URL for remove favorite")
                completion(false)
                return
            }

            guard var components = URLComponents(string: serverBaseUrl + "/api/v1/favorites/\(favoriteId)") else {
                shareLog("ERROR: Invalid remove favorite URL for id \(favoriteId)")
                completion(false)
                return
            }

            components.queryItems = [
                URLQueryItem(name: "user_id", value: self.getUserId())
            ]

            guard let url = components.url else {
                shareLog("ERROR: Failed to construct remove favorite URL")
                completion(false)
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.timeoutInterval = 10.0

            URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
                guard let self = self else {
                    DispatchQueue.main.async { completion(false) }
                    return
                }

                if let error = error {
                    shareLog("ERROR: Remove favorite request failed: \(error.localizedDescription)")
                    DispatchQueue.main.async { completion(false) }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    shareLog("ERROR: Remove favorite response missing HTTP status")
                    DispatchQueue.main.async { completion(false) }
                    return
                }

                shareLog("Remove favorite response status: \(httpResponse.statusCode)")

                guard httpResponse.statusCode == 200 else {
                    DispatchQueue.main.async { completion(false) }
                    return
                }

                DispatchQueue.main.async {
                    self.favoriteIdByProductId.removeValue(forKey: product.id)
                    completion(true)
                }
            }.resume()
        }
    }

    private func ensureFavoriteId(
        for productId: String,
        completion: @escaping (String?) -> Void
    ) {
        if let cachedId = favoriteIdByProductId[productId] {
            completion(cachedId)
            return
        }

        updateFavoriteMappings(for: [productId]) { [weak self] mappings in
            guard let self = self else {
                completion(nil)
                return
            }

            let resolvedId = mappings[productId] ?? self.favoriteIdByProductId[productId]
            if let resolvedId = resolvedId {
                shareLog("Resolved favorite_id \(resolvedId) for product \(productId)")
            } else {
                shareLog("WARNING: Unable to resolve favorite_id for product \(productId)")
            }
            completion(resolvedId)
        }
    }

    private func updateFavoriteMappings(
        for productIds: [String],
        completion: (([String: String]) -> Void)? = nil
    ) {
        let uniqueIds = Array(Set(productIds))
        let unresolvedIds = uniqueIds.filter { favoriteIdByProductId[$0] == nil }

        if !uniqueIds.isEmpty && unresolvedIds.isEmpty {
            DispatchQueue.main.async { completion?([:]) }
            return
        }

        guard let serverBaseUrl = getServerBaseUrl() else {
            shareLog("Cannot refresh favorite mappings - no server URL available")
            DispatchQueue.main.async { completion?([:]) }
            return
        }

        let userId = getUserId()
        var components = URLComponents(string: serverBaseUrl + "/api/v1/users/\(userId)/favorites")
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "200"),
            URLQueryItem(name: "offset", value: "0")
        ]

        guard let url = components?.url else {
            shareLog("Invalid URL when refreshing favorite mappings")
            DispatchQueue.main.async { completion?([:]) }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0

        let filterSet: Set<String>? = uniqueIds.isEmpty ? nil : Set(unresolvedIds)
        let fetchDescriptionText: String
        if let filterSet = filterSet {
            fetchDescriptionText = "\(filterSet.count)"
        } else {
            fetchDescriptionText = "all available"
        }
        shareLog("Refreshing favorite mappings for \(fetchDescriptionText) products (requested \(uniqueIds.count))")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                DispatchQueue.main.async { completion?([:]) }
                return
            }

            var mappingUpdates: [String: String] = [:]

            if let error = error {
                shareLog("ERROR: Favorite mappings fetch failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion?(mappingUpdates) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                shareLog("ERROR: Favorite mappings response missing HTTP status")
                DispatchQueue.main.async { completion?(mappingUpdates) }
                return
            }

            shareLog("Favorite mappings fetch status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200, let data = data else {
                shareLog("Favorite mappings fetch failed or returned no data")
                DispatchQueue.main.async { completion?(mappingUpdates) }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let favorites = json["favorites"] as? [[String: Any]] {
                    for entry in favorites {
                        guard
                            let productId = entry["product_id"] as? String,
                            let favoriteId = entry["id"] as? String
                        else { continue }

                        if let filterSet = filterSet, !filterSet.contains(productId) {
                            continue
                        }

                        mappingUpdates[productId] = favoriteId
                    }
                } else {
                    shareLog("WARNING: Unexpected favorites payload when refreshing mappings")
                }
            } catch {
                shareLog("ERROR: Failed to parse favorite mappings: \(error.localizedDescription)")
            }

            DispatchQueue.main.async {
                if !mappingUpdates.isEmpty {
                    self.favoriteIdByProductId.merge(mappingUpdates) { _, new in new }
                }
                completion?(mappingUpdates)
            }
        }.resume()
    }

    private func getUserId() -> String {
        // Get Supabase auth user ID from shared UserDefaults
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            shareLog("ERROR: Could not access shared UserDefaults with appGroupId: \(appGroupId)")
            if let deviceId = UIDevice.current.identifierForVendor?.uuidString {
                return deviceId
            }
            return "anonymous"
        }

        // Check if user is authenticated
        let isAuthenticated = defaults.bool(forKey: "is_authenticated")
        shareLog("getUserId - isAuthenticated flag: \(isAuthenticated)")

        // Try to get Supabase user ID
        if let userId = defaults.string(forKey: "supabase_user_id") {
            if userId.isEmpty {
                shareLog("WARNING: supabase_user_id exists but is EMPTY")
            } else {
                shareLog("getUserId - Using Supabase user ID: \(userId)")
                return userId
            }
        } else {
            shareLog("WARNING: supabase_user_id key NOT FOUND in UserDefaults")
        }

        // Debug: List all keys in UserDefaults
        let allKeys = Array(defaults.dictionaryRepresentation().keys)
        shareLog("DEBUG: All UserDefaults keys: \(allKeys.joined(separator: ", "))")

        // Fallback to device ID (should not happen if user is authenticated)
        shareLog("WARNING: No Supabase user ID found, using device ID fallback")
        if let deviceId = UIDevice.current.identifierForVendor?.uuidString {
            shareLog("Using device ID: \(deviceId)")
            return deviceId
        }
        return "anonymous"
    }

    private func extractInstagramUsername(from url: String) -> String? {
        // Extract username from Instagram URLs like:
        // https://www.instagram.com/username/...
        // https://instagram.com/username/...
        if let regex = try? NSRegularExpression(pattern: "instagram\\.com/([^/]+)", options: []),
           let match = regex.firstMatch(in: url, options: [], range: NSRange(url.startIndex..., in: url)),
           match.numberOfRanges > 1,
           let usernameRange = Range(match.range(at: 1), in: url) {
            let username = String(url[usernameRange])
            // Filter out non-username paths like 'p', 'reel', 'tv', etc.
            if !["p", "reel", "tv", "stories", "explore"].contains(username.lowercased()) {
                return username
            }
        }
        return nil
    }

    // Custom activity item source for rich share metadata
    private class SnaplookShareItem: NSObject, UIActivityItemSource {
        let imageURL: URL
        let imageTitle: String
        let imageSubject: String

        init(imageURL: URL, title: String, subject: String) {
            self.imageURL = imageURL
            self.imageTitle = title
            self.imageSubject = subject
            super.init()
        }

        func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
            return imageURL
        }

        func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
            return imageURL
        }

        func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
            return imageSubject
        }

        func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
            return "public.jpeg"
        }

        func activityViewController(_ activityViewController: UIActivityViewController, thumbnailImageForActivityType activityType: UIActivity.ActivityType?, suggestedSize size: CGSize) -> UIImage? {
            return UIImage(contentsOfFile: imageURL.path)
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

        // Show loading indicator while preparing share content
        let loadingView = UIView(frame: view.bounds)
        loadingView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        loadingView.tag = 9999 // Tag for easy removal

        let loadingContainer = UIView()
        loadingContainer.backgroundColor = UIColor.systemBackground
        loadingContainer.layer.cornerRadius = 12
        loadingContainer.translatesAutoresizingMaskIntoConstraints = false

        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        let loadingLabel = UILabel()
        loadingLabel.text = "Preparing to share..."
        loadingLabel.font = .systemFont(ofSize: 14, weight: .medium)
        loadingLabel.textColor = .label
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false

        loadingContainer.addSubview(activityIndicator)
        loadingContainer.addSubview(loadingLabel)
        loadingView.addSubview(loadingContainer)
        view.addSubview(loadingView)

        NSLayoutConstraint.activate([
            loadingContainer.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            loadingContainer.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor),
            loadingContainer.widthAnchor.constraint(equalToConstant: 200),
            loadingContainer.heightAnchor.constraint(equalToConstant: 80),

            activityIndicator.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: loadingContainer.topAnchor, constant: 16),

            loadingLabel.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 8)
        ])

        // Prepare share content asynchronously to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            self.prepareAndPresentShare(loadingView: loadingView)
        }
    }

    private func prepareAndPresentShare(loadingView: UIView) {
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

        // Prepare items to share - build array with image first for proper iOS preview
        var itemsToShare: [Any] = []
        var shareImage: UIImage?

        // Try to get the analyzed image
        if let imageData = analyzedImageData {
            shareLog("Attempting to create UIImage from \(imageData.count) bytes")
            if let image = UIImage(data: imageData) {
                shareImage = image
                shareLog("✅ Successfully loaded analyzed image (size: \(image.size))")
            } else {
                shareLog("❌ ERROR: Failed to create UIImage from imageData")
            }
        } else {
            shareLog("❌ WARNING: analyzedImageData is nil - trying fallback")
        }

        // Fallback: Try to use the first product's image if original image unavailable
        if shareImage == nil && !detectionResults.isEmpty {
            if let firstProduct = detectionResults.first {
                let imageUrlString = firstProduct.image_url
                if !imageUrlString.isEmpty, let imageUrl = URL(string: imageUrlString) {
                    shareLog("Fallback: Attempting to download product image from: \(imageUrlString)")

                    // Download image synchronously (we're already in share flow)
                    if let imageData = try? Data(contentsOf: imageUrl),
                       let image = UIImage(data: imageData) {
                        shareImage = image
                        shareLog("✅ Successfully loaded product image as fallback (size: \(image.size))")
                    } else {
                        shareLog("❌ Failed to download fallback image")
                    }
                }
            }
        }

        // Build items array: image MUST be first for iOS preview thumbnail
        // iOS share sheet preview works best with file URLs, not UIImage objects
        if let image = shareImage {
            // Simple, clean filename
            let tempDir = FileManager.default.temporaryDirectory
            let imageFileName = "Snaplook-Fashion-Matches.jpg"
            let imageURL = tempDir.appendingPathComponent(imageFileName)

            // Build subject/subtitle for share sheet based on source
            var subject = "Snaplook Fashion Match"

            // Extract Instagram username if available
            var instagramUsername: String?
            if let instagramUrl = pendingInstagramUrl {
                let pattern = "instagram\\.com/([^/?]+)"
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: instagramUrl, range: NSRange(instagramUrl.startIndex..., in: instagramUrl)) {
                    if let usernameRange = Range(match.range(at: 1), in: instagramUrl) {
                        instagramUsername = String(instagramUrl[usernameRange])
                    }
                }
            }

            if let username = instagramUsername {
                subject = "from Instagram @\(username)"
            } else if let sourceApp = readSourceApplicationBundleIdentifier() {
                if sourceApp.contains("instagram") {
                    subject = "from Instagram"
                } else if sourceApp.contains("photos") {
                    subject = "from Photos"
                }
            }

            if let jpegData = image.jpegData(compressionQuality: 0.9) {
                do {
                    try jpegData.write(to: imageURL)

                    // Use custom activity item source for rich metadata
                    let shareItem = SnaplookShareItem(
                        imageURL: imageURL,
                        title: imageFileName,
                        subject: subject
                    )
                    itemsToShare.append(shareItem)
                    itemsToShare.append(shareText)
                    shareLog("✅ Share items: [custom image item, text] - wrote temp file: \(imageFileName)")
                    shareLog("   Subject: \(subject)")
                } catch {
                    shareLog("❌ Failed to write temp image file: \(error)")
                    // Fallback to UIImage if file write fails
                    itemsToShare.append(image)
                    itemsToShare.append(shareText)
                    shareLog("⚠️ Fallback: using UIImage instead of file URL")
                }
            } else {
                shareLog("❌ Failed to convert image to JPEG")
                itemsToShare.append(image)
                itemsToShare.append(shareText)
                shareLog("⚠️ Fallback: using UIImage instead of JPEG")
            }
        } else {
            itemsToShare.append(shareText)
            shareLog("⚠️ Share items: [text only] - no image available")
        }

        // Present iOS share sheet on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Remove loading view
            loadingView.removeFromSuperview()

            let activityVC = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)

            // Exclude some activities that don't make sense
            activityVC.excludedActivityTypes = [
                .assignToContact,
                .addToReadingList,
                .openInIBooks
            ]

            // For iPad support
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            self.present(activityVC, animated: true) {
                shareLog("Share sheet presented successfully")
            }
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
                shareLog("NORMAL FLOW: Saved file to UserDefaults")
            } catch {
                shareLog("ERROR writing file in normal flow: \(error.localizedDescription)")
            }
        }

        // Save platform type for Flutter to read
        if pendingPlatformType == nil {
            pendingPlatformType = inferredPlatformType
        }

        if let platformType = pendingPlatformType {
            let userDefaults = UserDefaults(suiteName: appGroupId)
            userDefaults?.set(platformType, forKey: "pending_platform_type")
            userDefaults?.synchronize()
            shareLog("Saved pending platform type: \(platformType)")
        }

        saveAndRedirect()
    }

    private func extractInstagramImageUrls(from html: String) -> [String] {
        var urls: [String] = []

        func cleaned(_ raw: String) -> String {
            return sanitizeInstagramURLString(raw)
        }

        func appendIfValid(_ candidate: String) {
            guard !candidate.isEmpty,
                  !candidate.contains("150x150"),
                  !candidate.contains("profile"),
                  !urls.contains(candidate) else { return }
            urls.append(candidate)
        }

        // Fast path: first ig_cache_key in JSON
        let cacheKeyPattern = "\"src\":\"(https:\\\\/\\\\/scontent[^\"]+?ig_cache_key[^\"]*)\""
        if let regex = try? NSRegularExpression(pattern: cacheKeyPattern, options: []) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            if let match = regex.firstMatch(in: html, options: [], range: nsrange),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: html) {
                appendIfValid(cleaned(String(html[range])))
            }
        }

        if !urls.isEmpty { return urls }

        // Fast path: first display_url
        let displayPattern = "\"display_url\"\\s*:\\s*\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: displayPattern, options: []) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            if let match = regex.firstMatch(in: html, options: [], range: nsrange),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: html) {
                appendIfValid(cleaned(String(html[range])))
            }
        }

        if !urls.isEmpty { return urls }

        // img src (limit to first 5) - only ig_cache_key to avoid low-quality/blocked URLs
        let imgPattern = "<img[^>]+src=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: imgPattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            var count = 0
            regex.enumerateMatches(in: html, options: [], range: nsrange) { match, _, stop in
                guard count < 5,
                      let match = match,
                      match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: html) else { return }
                let candidate = cleaned(String(html[range]))
                if !candidate.contains("ig_cache_key") { return }
                appendIfValid(candidate)
                count += 1
                if count >= 5 { stop.pointee = true }
            }
        }

        if !urls.isEmpty { return urls }

        // og:image fallback
        let ogPattern = "<meta property=\"og:image\" content=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: ogPattern, options: [.caseInsensitive]) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
            if let match = regex.firstMatch(in: html, options: [], range: nsrange),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: html) {
                appendIfValid(cleaned(String(html[range])))
            }
        }

        return urls
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

    private func performRedirectFallback(to url: URL) -> Bool {
        shareLog("Using responder chain fallback to open URL")
        var responder: UIResponder? = self
        let selectorOpenURL = sel_registerName("openURL:")
        while let current = responder {
            if current.responds(to: selectorOpenURL) {
                _ = current.perform(selectorOpenURL, with: url)
                shareLog("Opened URL via responder chain")
                return true
            }
            responder = current.next
        }
        shareLog("Responder chain fallback could not find a responder to open URL")
        return false
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

    private func showImagePreview(imageData: Data) {
        shareLog("Showing image preview")

        // Hide loading UI
        hideLoadingUI()

        // Store image data for later analysis
        analyzedImageData = imageData

        // Create preview overlay
        let overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor.systemBackground
        overlay.tag = 9997 // Tag to identify preview overlay

        // Image view with aspect-fill to cover entire rectangle
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tag = 9998 // Tag to identify image view for later updates

        if let image = UIImage(data: imageData) {
            imageView.image = image
            shareLog("Preview image loaded - size: \(image.size)")
        } else {
            shareLog("ERROR: Failed to create UIImage from imageData")
            dismissWithError()
            return
        }

        // Store reference for later updates
        previewImageView = imageView
        overlay.addSubview(imageView)

        // "Crop" button (secondary style - white with border)
        let cropButton = UIButton(type: .system)
        cropButton.setTitle("Crop", for: .normal)
        cropButton.titleLabel?.font = UIFont(name: "PlusJakartaSans-SemiBold", size: 16)
            ?? .systemFont(ofSize: 16, weight: .semibold)
        cropButton.backgroundColor = .white
        cropButton.setTitleColor(UIColor(red: 28/255, green: 28/255, blue: 37/255, alpha: 1.0), for: .normal)
        cropButton.layer.borderWidth = 1.5
        cropButton.layer.borderColor = UIColor(red: 229/255, green: 231/255, blue: 235/255, alpha: 1.0).cgColor
        cropButton.layer.cornerRadius = 28
        cropButton.translatesAutoresizingMaskIntoConstraints = false
        cropButton.addTarget(self, action: #selector(cropButtonTapped), for: .touchUpInside)

        overlay.addSubview(cropButton)

        // "Analyze" button at bottom (primary red style)
        let analyzeButton = UIButton(type: .system)
        analyzeButton.setTitle("Analyze", for: .normal)
        analyzeButton.titleLabel?.font = UIFont(name: "PlusJakartaSans-Bold", size: 16)
            ?? .systemFont(ofSize: 16, weight: .bold)
        analyzeButton.backgroundColor = UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0)
        analyzeButton.setTitleColor(.white, for: .normal)
        analyzeButton.layer.cornerRadius = 28
        analyzeButton.translatesAutoresizingMaskIntoConstraints = false
        analyzeButton.addTarget(self, action: #selector(analyzeFromPreviewTapped), for: .touchUpInside)

        overlay.addSubview(analyzeButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Image takes most of the space, with padding for header (logo + cancel button)
            imageView.topAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.topAnchor, constant: 70),
            imageView.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -20),
            imageView.bottomAnchor.constraint(equalTo: cropButton.topAnchor, constant: -16),

            // Crop button above analyze button
            cropButton.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 32),
            cropButton.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -32),
            cropButton.bottomAnchor.constraint(equalTo: analyzeButton.topAnchor, constant: -12),
            cropButton.heightAnchor.constraint(equalToConstant: 56),

            // Analyze button at bottom
            analyzeButton.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 32),
            analyzeButton.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -32),
            analyzeButton.bottomAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            analyzeButton.heightAnchor.constraint(equalToConstant: 56),
        ])

        view.addSubview(overlay)
        loadingView = overlay

        if let header = addResultsHeaderIfNeeded() {
            overlay.bringSubviewToFront(header)
        }

        hideDefaultUI()
        shareLog("Image preview displayed")
    }

    @objc private func analyzeFromPreviewTapped() {
        shareLog("Analyze button tapped from preview")

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Get the stored image data
        guard let imageData = analyzedImageData else {
            shareLog("ERROR: No image data available for analysis")
            dismissWithError()
            return
        }

        // Replace preview overlay with the standard loading UI used during detection
        hideLoadingUI()
        updateProcessingStatus("processing")
        setupLoadingUI()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.stopStatusPolling()
            self.startSmoothProgress()

            // Slow progress for detection phase (6-7 seconds to reach 96%)
            self.progressRateMultiplier = 0.25
            self.targetProgress = 0.96

            let rotatingMessages = [
                "Analyzing look...",
                "Finding similar items...",
                "Checking retailers...",
                "Finalizing results..."
            ]
            self.startStatusRotation(messages: rotatingMessages, interval: 2.0, stopAtLast: false)
        }

        // Start detection
        shareLog("Starting detection from preview with \(imageData.count) bytes")
        uploadAndDetect(imageData: imageData)
    }

    private func fadeInCropToolbarButtons(_ cropViewController: TOCropViewController) {
        UIView.animate(withDuration: 0.3, delay: 0.1, options: .curveEaseOut, animations: {
            cropViewController.toolbar.subviews.forEach { $0.alpha = 1.0 }
        }, completion: nil)
    }

    @objc private func cropButtonTapped() {
        shareLog("Crop button tapped")

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Get the current image
        guard let imageData = analyzedImageData,
              let image = UIImage(data: imageData) else {
            shareLog("ERROR: No image available for cropping")
            return
        }

        // Present crop view controller with proper layout handling
        let cropViewController = TOCropViewController(image: image)
        cropViewController.delegate = self
        cropViewController.aspectRatioPreset = .presetSquare
        cropViewController.aspectRatioLockEnabled = false
        cropViewController.resetAspectRatioEnabled = true
        cropViewController.aspectRatioPickerButtonHidden = false
        cropViewController.rotateButtonsHidden = false
        cropViewController.rotateClockwiseButtonHidden = true
        cropViewController.toolbar.clampButtonHidden = true

        // Hide toolbar buttons initially to prevent flash - they will fade in
        cropViewController.toolbar.doneTextButton.alpha = 0
        cropViewController.toolbar.cancelTextButton.alpha = 0
        cropViewController.toolbar.subviews.forEach { $0.alpha = 0 }

        // Set toolbar buttons tint to white for better visibility
        let snaplookRed = UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0)
        cropViewController.toolbar.tintColor = .white
        cropViewController.toolbar.doneTextButton.setTitleColor(snaplookRed, for: .normal)
        cropViewController.toolbar.doneTextButton.setTitleColor(snaplookRed.withAlphaComponent(0.8), for: .highlighted)

        // Wrap in navigation controller for proper safe area handling in Share Extension
        let navController = UINavigationController(rootViewController: cropViewController)
        navController.modalPresentationStyle = .fullScreen
        navController.isNavigationBarHidden = true

        shareLog("Presenting crop view controller")
        present(navController, animated: true) {
            // Fade in the built-in toolbar buttons (Done/Cancel + tools)
            self.fadeInCropToolbarButtons(cropViewController)
        }
    }

    private func startSmoothProgress() {
        stopSmoothProgress()

        currentProgress = 0.0
        targetProgress = 0.0

        DispatchQueue.main.async { [weak self] in
            self?.progressView?.setProgress(0.0, animated: false)

            self?.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
                guard let self = self else { return }

                // Smoothly increment toward target with adaptive speed
                if self.currentProgress < self.targetProgress {
                    let remaining = max(self.targetProgress - self.currentProgress, 0)
                    // Adaptive increment: faster when far, slower when close; scaled per source
                    let increment: Float = max(remaining * 0.08 * self.progressRateMultiplier,
                                               0.004 * self.progressRateMultiplier)
                    let cappedIncrement = min(increment, 0.03) // prevent huge jumps
                    self.currentProgress = min(self.currentProgress + cappedIncrement, self.targetProgress)
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

    private func configureProgressProfile(for platform: String?) {
        let normalized = platform?.lowercased()
        if let normalized = normalized,
           ["instagram", "tiktok", "pinterest", "youtube", "facebook", "twitter", "x", "snapchat"].contains(normalized) {
            // Slower crawl for heavier/social flows
            progressRateMultiplier = 1.0
            previewTargetCap = 0.92
            detectTargetCap = 0.96
        } else {
            // Faster ramp for direct/browser shares
            progressRateMultiplier = 1.6
            previewTargetCap = 0.98
            detectTargetCap = 0.995
        }
    }

    private func updateProgress(_ progress: Float, status: String) {
        // Never regress progress; only move forward
        targetProgress = max(targetProgress, progress)

        if isPhotosSourceApp {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.statusLabel?.text = self.photoImportStatusMessage
                shareLog("Progress: \(Int(progress * 100))% - \(status)")
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.statusLabel?.text = status
            shareLog("Progress: \(Int(progress * 100))% - \(status)")
        }
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
                guard let timer = self.statusRotationTimer, timer.isValid else {
                    self.stopStatusRotation()
                    return
                }

                // Safety check: Stop if messages array became empty
                guard !self.currentStatusMessages.isEmpty else {
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
        openAppButton.titleLabel?.font = UIFont(name: "PlusJakartaSans-Bold", size: 16)
            ?? .systemFont(ofSize: 16, weight: .bold)
        openAppButton.setTitleColor(.white, for: .normal)
        openAppButton.backgroundColor = UIColor(red: 242/255, green: 0, blue: 60/255, alpha: 1.0)
        openAppButton.layer.cornerRadius = 28
        openAppButton.addTarget(self, action: #selector(openAppTapped), for: .touchUpInside)

        // "Cancel" button (pill-shaped with border)
        let cancelActionButton = UIButton(type: .system)
        cancelActionButton.setTitle("Cancel", for: .normal)
        cancelActionButton.titleLabel?.font = UIFont(name: "PlusJakartaSans-Bold", size: 16)
            ?? .systemFont(ofSize: 16, weight: .bold)
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

        // Use the same URL scheme that works for "Analyze in app"
        loadIds()
        guard let url = URL(string: "\(kSchemePrefix)-\(hostAppBundleIdentifier):share") else {
            shareLog("ERROR: Failed to create app URL")
            cancelLoginRequiredTapped()
            return
        }

        // Use responder chain to open the app (same as working Analyze in app flow)
        shareLog("Opening app with URL: \(url.absoluteString)")

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

        // Close the extension after opening app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.finishExtensionRequest()
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

    private func openURLViaResponderChain(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        let selector = NSSelectorFromString("openURL:")
        while let currentResponder = responder {
            if currentResponder.responds(to: selector) {
                currentResponder.perform(selector, with: url)
                return true
            }
            responder = currentResponder.next
        }
        return false
    }

    @objc private func cancelImportTapped() {
        shareLog("Cancel tapped")

        // End extended execution
        endExtendedExecution()

        loadingHideWorkItem?.cancel()
        loadingHideWorkItem = nil

        // Tear down immediately so the sheet can animate closed naturally
        clearSharedData()
        hideLoadingUI()
        hideDefaultUI()
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

        // Check if user already analyzed via "Analyze now" - if so, just pass the search_id
        if let searchId = currentSearchId {
            shareLog("User already analyzed - opening app with search_id: \(searchId)")

            // Save search_id to UserDefaults so Flutter can read it
            let userDefaults = UserDefaults(suiteName: appGroupId)
            userDefaults?.set(searchId, forKey: "search_id")
            userDefaults?.set("pending", forKey: kProcessingStatusKey)
            let sessionId = UUID().uuidString
            userDefaults?.set(sessionId, forKey: kProcessingSessionKey)
            userDefaults?.synchronize()
            shareLog("Saved search_id to UserDefaults: \(searchId)")

            // Redirect to host app without file paths
            loadIds()
            guard let redirectURL = URL(string: "\(kSchemePrefix)-\(hostAppBundleIdentifier):share") else {
                shareLog("ERROR: Failed to build redirect URL")
                dismissWithError()
                return
            }

            enqueueRedirect(to: redirectURL, minimumDuration: 0.5) { [weak self] in
                self?.finishExtensionRequest()
            }
            return
        }

        // Check if this is a URL (before download) or direct image (after download)
        if let socialUrl = pendingInstagramUrl {
            let platformName = getPlatformDisplayName(pendingPlatformType)
            shareLog("Downloading \(platformName) media and saving to app")

            // Start download process
            updateProcessingStatus("processing")
            setupLoadingUI()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.startSmoothProgress()
                self.targetProgress = 0.92
                self.updateProgress(0.0, status: "Opening Snaplook...")
            }

            let downloadFunction = getDownloadFunction(for: pendingPlatformType)
            downloadFunction(socialUrl) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let downloaded):
                    if downloaded.isEmpty {
                        shareLog("\(platformName) download succeeded but returned no files")
                        self.dismissWithError()
                    } else {
                        self.sharedMedia.append(contentsOf: downloaded)
                        shareLog("Downloaded and saved \(downloaded.count) \(platformName) file(s)")

                        // Update progress to completion
                        self.targetProgress = 1.0
                        self.updateProgress(1.0, status: "Opening Snaplook...")

                        // Delay to allow progress bar to complete fully before redirecting
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                            // Stop smooth progress to lock at 100%
                            self.stopSmoothProgress()
                            self.saveAndRedirect(message: self.pendingInstagramUrl)
                        }
                    }

                    // DON'T call pendingInstagramCompletion - we're handling redirect ourselves
                    // Calling it would trigger maybeFinalizeShare() and cause a double redirect
                    self.pendingInstagramCompletion = nil
                    self.pendingInstagramUrl = nil

                case .failure(let error):
                    shareLog("ERROR: \(platformName) download failed - \(error.localizedDescription)")
                    self.dismissWithError()
                }
            }
        } else if let imageData = pendingImageData,
                  let sharedFile = pendingSharedFile,
                  let fileURL = URL(string: sharedFile.path) {
            shareLog("Saving direct image to app")

            // Start UI setup for direct image shares
            updateProcessingStatus("processing")
            setupLoadingUI()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                // Start smooth progress animation
                self.stopStatusPolling()
                self.startSmoothProgress()
                self.targetProgress = 0.98
                self.updateProgress(0.0, status: "Opening Snaplook...")

                // Complete after brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    self?.targetProgress = 1.0
                }
            }

            do {
                // Write the file to shared container
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
                try imageData.write(to: fileURL, options: .atomic)
                shareLog("Saved image to shared container: \(fileURL.path)")

                // Add to shared media array
                sharedMedia.append(sharedFile)

                // Delay to allow progress bar to complete fully before redirecting
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
                    guard let self = self else { return }
                    // Stop smooth progress to lock at 100%
                    self.stopSmoothProgress()
                    self.saveAndRedirect(message: self.pendingImageUrl)
                }

            } catch {
                shareLog("ERROR: Failed to save image - \(error.localizedDescription)")
            }
        } else if !sharedMedia.isEmpty {
            // Fallback: We have media in sharedMedia (e.g., from a non-social-media URL)
            shareLog("Using already-processed media from sharedMedia array")

            // Start UI setup
            updateProcessingStatus("processing")
            setupLoadingUI()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                // Start smooth progress animation
                self.stopStatusPolling()
                self.startSmoothProgress()
                self.targetProgress = 0.98
                self.updateProgress(0.0, status: "Opening Snaplook...")

                // Complete and redirect
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    guard let self = self else { return }
                    self.targetProgress = 1.0

                    // Delay to allow progress bar to complete fully before redirecting
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.stopSmoothProgress()
                        self?.saveAndRedirect(message: nil)
                    }
                }
            }
        } else {
            shareLog("ERROR: No pending URL, image data, or shared media")
        }
    }

    @objc private func analyzeNowTapped() {
        shareLog("Analyze now tapped - starting detection")
        shareLog("DEBUG: pendingInstagramUrl=\(pendingInstagramUrl != nil ? "SET" : "NIL"), pendingPlatformType=\(pendingPlatformType ?? "NIL"), sharedMedia.count=\(sharedMedia.count)")

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Remove choice UI
        hideLoadingUI()

        // Check if this is a URL (before download) or direct image (after download)
        if let socialUrl = pendingInstagramUrl {
            let platformName = getPlatformDisplayName(pendingPlatformType)
            let shouldCheckCache = (pendingPlatformType == "instagram")

            // Start UI setup early
            updateProcessingStatus("processing")
            setupLoadingUI()

            let proceedToDownload: () -> Void = { [weak self] in
                guard let self = self else { return }

                // Instagram gets special treatment with rotating messages
                let isInstagram = (self.pendingPlatformType == "instagram")

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.startSmoothProgress()

                    if isInstagram {
                        // Instagram: rotating messages for more engaging UX
                        let instagramMessages = [
                            "Getting image...",
                            "Downloading photo...",
                            "Fetching photo...",
                            "Almost there..."
                        ]
                        self.startStatusRotation(messages: instagramMessages, interval: 2.0)

                        // Slow down progress rate for Instagram to match 4-5 second download time
                        // Normal rate is 1.0, we use 0.35 to make it reach 92% in ~4-5 seconds
                        self.progressRateMultiplier = 0.35
                        self.targetProgress = 0.92
                    } else {
                        // TikTok, Pinterest, etc.: simple single message
                        self.targetProgress = 0.92
                        self.updateProgress(0.0, status: "Loading preview...")
                    }
                }

                let downloadFunction = self.getDownloadFunction(for: self.pendingPlatformType)
                downloadFunction(socialUrl) { [weak self] result in
                    guard let self = self else { return }

                    switch result {
                    case .success(let downloaded):
                        if downloaded.isEmpty {
                            shareLog("\(platformName) download succeeded but returned no files")
                            self.dismissWithError()
                        } else {
                            // Get the first downloaded file and show preview
                            if let firstFile = downloaded.first,
                               let fileURL = URL(string: firstFile.path),
                               let imageData = try? Data(contentsOf: fileURL) {
                                shareLog("Downloaded \(platformName) image (\(imageData.count) bytes) - showing preview")

                                // Update progress to completion
                                if isInstagram {
                                    self.stopStatusRotation()
                                }
                                self.targetProgress = 1.0
                                self.updateProgress(1.0, status: "Loading preview...")

                                // Delay to allow progress bar to complete fully before showing preview
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                                    // Stop smooth progress to lock at 100%
                                    self.stopSmoothProgress()
                                    self.showImagePreview(imageData: imageData)
                                }
                            } else {
                                shareLog("ERROR: Could not read downloaded \(platformName) file")
                                self.dismissWithError()
                            }
                        }

                        // DON'T call completion - we're showing preview, not redirecting
                        self.pendingInstagramCompletion = nil
                        self.pendingInstagramUrl = nil

                    case .failure(let error):
                        shareLog("ERROR: \(platformName) download failed - \(error.localizedDescription)")
                        self.dismissWithError()
                    }
                }
            }

            if shouldCheckCache {
                checkCacheForInstagram(url: socialUrl) { [weak self] isCached in
                    guard let self = self else { return }

                    if isCached {
                        shareLog("Cache HIT - skipping \(platformName) download")
                        // Results already displayed by checkCacheForInstagram
                        self.pendingInstagramCompletion = nil
                        self.pendingInstagramUrl = nil
                    } else {
                        shareLog("Cache MISS - proceeding with \(platformName) download")
                        proceedToDownload()
                    }
                }
            } else {
                proceedToDownload()
            }
        } else if let imageData = pendingImageData {
            shareLog("Showing preview for direct image with \(imageData.count) bytes")

            // Start UI setup for direct image shares
            updateProcessingStatus("processing")
            setupLoadingUI()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                // Start smooth progress animation
                self.stopStatusPolling()
                self.startSmoothProgress()
                self.targetProgress = 0.98
                self.updateProgress(0.0, status: "Loading preview...")

                // Complete and show preview
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    guard let self = self else { return }
                    self.targetProgress = 1.0

                    // Show preview after progress completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.stopSmoothProgress()
                        self?.showImagePreview(imageData: imageData)
                    }
                }
            }
        } else if !sharedMedia.isEmpty {
            // Fallback: For non-social-media URLs, we can't analyze directly
            // Just redirect to the app with the URL
            shareLog("Non-social-media URL - redirecting to app for analysis")
            saveAndRedirect(message: nil)
        } else {
            shareLog("ERROR: No pending URL, image data, or shared media")
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
        let isFavorited = favoritedProductIds.contains(result.id)
        cell.configure(with: result, isFavorited: isFavorited)

        // Set favorite toggle callback
        let currentIndexPath = indexPath
        cell.onFavoriteToggle = { [weak self] product, isFavorite in
            guard let self = self else { return }

            if isFavorite {
                self.favoritedProductIds.insert(product.id)
                self.addFavoriteToBackend(product: product) { success in
                    if !success {
                        shareLog("Failed to add favorite to backend")
                        self.favoritedProductIds.remove(product.id)
                        if let tableView = self.resultsTableView,
                           currentIndexPath.row < self.filteredResults.count {
                            tableView.reloadRows(at: [currentIndexPath], with: .none)
                        }
                    }
                }
            } else {
                self.favoritedProductIds.remove(product.id)
                self.removeFavoriteFromBackend(product: product) { success in
                    if success {
                        shareLog("Removed favorite for product \(product.id)")
                    } else {
                        shareLog("Failed to remove favorite from backend")
                        self.favoritedProductIds.insert(product.id)
                        if let tableView = self.resultsTableView,
                           currentIndexPath.row < self.filteredResults.count {
                            tableView.reloadRows(at: [currentIndexPath], with: .none)
                        }
                    }
                }
            }
        }

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

        // Embed in a navigation controller
        let navController = UINavigationController(rootViewController: webVC)
        navController.modalPresentationStyle = .fullScreen
        navController.isNavigationBarHidden = true // WebViewController has its own toolbar
        navController.modalPresentationCapturesStatusBarAppearance = true // Let WebVC control status bar

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
        label.font = UIFont(name: "PlusJakartaSans-Bold", size: 16)
            ?? .systemFont(ofSize: 16, weight: .bold)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let productNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PlusJakartaSans-Medium", size: 12)
            ?? .systemFont(ofSize: 12, weight: .medium)
        // Match Flutter onSurface color (0xFF1c1c25) for consistency with in-app results
        label.textColor = UIColor(red: 0x1c/255.0, green: 0x1c/255.0, blue: 0x25/255.0, alpha: 1.0)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PlusJakartaSans-Bold", size: 16)
            ?? .systemFont(ofSize: 16, weight: .bold)
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

    private let chevronImageView: UIImageView = {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        iv.image = UIImage(systemName: "chevron.right", withConfiguration: config)
        iv.tintColor = UIColor.tertiaryLabel
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private var isFavorite = false
    private var product: DetectionResultItem?
    var onFavoriteToggle: ((DetectionResultItem, Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // Create a vertical stack for the text labels (with spacer to keep price anchored at bottom)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        let textStackView = UIStackView(arrangedSubviews: [brandLabel, productNameLabel, spacer, priceLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 4
        textStackView.distribution = .fill
        textStackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(productImageView)
        contentView.addSubview(favoriteButton)
        contentView.addSubview(textStackView)
        contentView.addSubview(chevronImageView)
        favoriteButton.addTarget(self, action: #selector(favoriteTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            productImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            productImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            productImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            productImageView.widthAnchor.constraint(equalToConstant: 80),
            productImageView.heightAnchor.constraint(equalToConstant: 80),

            favoriteButton.bottomAnchor.constraint(equalTo: productImageView.bottomAnchor, constant: -6),
            favoriteButton.trailingAnchor.constraint(equalTo: productImageView.trailingAnchor, constant: -6),
            favoriteButton.widthAnchor.constraint(equalToConstant: 32),
            favoriteButton.heightAnchor.constraint(equalToConstant: 32),

            chevronImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 16),
            chevronImageView.heightAnchor.constraint(equalToConstant: 16),

            textStackView.leadingAnchor.constraint(equalTo: productImageView.trailingAnchor, constant: 12),
            textStackView.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -18),
            textStackView.topAnchor.constraint(equalTo: productImageView.topAnchor),
            textStackView.bottomAnchor.constraint(equalTo: productImageView.bottomAnchor),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 110)
        ])
    }

    func configure(with result: DetectionResultItem, isFavorited: Bool = false) {
        // Store product for favorite callback
        self.product = result
        let brandText: String
        if let brand = result.brand, !brand.isEmpty {
            brandText = brand
        } else {
            brandText = "Snaplook match"
        }
        // Match in-app behavior: always show brand in uppercase
        brandLabel.text = brandText.uppercased()
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

        // Set favorite state (checking if already favorited)
        isFavorite = isFavorited
        updateFavoriteAppearance(animated: false)
    }

    @objc private func favoriteTapped() {
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()

        isFavorite.toggle()
        updateFavoriteAppearance(animated: true)

        // Call backend API via callback
        if let product = product {
            onFavoriteToggle?(product, isFavorite)
        }
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

extension RSIShareViewController: TOCropViewControllerDelegate {
    public func cropViewController(_ cropViewController: TOCropViewController, didCropTo image: UIImage, with cropRect: CGRect, angle: Int) {
        shareLog("Image cropped successfully - size: \(image.size)")

        // Convert cropped image to JPEG data with high quality
        guard let croppedImageData = image.jpegData(compressionQuality: 0.9) else {
            shareLog("ERROR: Failed to convert cropped image to data")
            cropViewController.dismiss(animated: true, completion: nil)
            return
        }

        shareLog("Cropped image data: \(croppedImageData.count) bytes")

        // Update the stored image data with cropped version
        analyzedImageData = croppedImageData

        // Update the preview image
        if let previewImageView = previewImageView {
            UIView.transition(with: previewImageView, duration: 0.3, options: .transitionCrossDissolve, animations: {
                previewImageView.image = image
            }, completion: nil)
            shareLog("Updated preview with cropped image")
        }

        // Dismiss crop view controller
        cropViewController.dismiss(animated: true) {
            shareLog("Crop view controller dismissed")
        }
    }

    public func cropViewController(_ cropViewController: TOCropViewController, didFinishCancelled cancelled: Bool) {
        shareLog("Crop cancelled by user")
        cropViewController.dismiss(animated: true, completion: nil)
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

    /// Resolve a relative URL string against this base URL
    func resolve(_ relativeString: String) -> String? {
        if relativeString.hasPrefix("http://") || relativeString.hasPrefix("https://") {
            return relativeString
        }

        if relativeString.hasPrefix("//") {
            return "\(self.scheme ?? "https"):\(relativeString)"
        }

        if let resolved = URL(string: relativeString, relativeTo: self) {
            return resolved.absoluteString
        }

        return nil
    }
}








