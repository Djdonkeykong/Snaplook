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

@available(swift, introduced: 5.0)
open class RSIShareViewController: SLComposeServiceViewController {
    var hostAppBundleIdentifier = ""
    var appGroupId = ""
    var sharedMedia: [SharedMediaFile] = []
    private var loadingView: UIView?
    private var loadingShownAt: Date?
    private var loadingHideWorkItem: DispatchWorkItem?

    open func shouldAutoRedirect() -> Bool { true }

    open override func isContentValid() -> Bool { true }

    open override func viewDidLoad() {
        super.viewDidLoad()
        loadIds()
        sharedMedia.removeAll()
        shareLog("View did load - cleared sharedMedia array")
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            shareLog("Resolved container URL: \(containerURL.path)")
        } else {
            shareLog("ERROR: Failed to resolve container URL for \(appGroupId)")
        }
        loadingHideWorkItem?.cancel()
        setupLoadingUI()
    }

    open override func didSelectPost() {
        shareLog("didSelectPost invoked")
        saveAndRedirect(message: contentText)
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let content = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = content.attachments else {
            shareLog("No attachments found on extension context")
            return
        }

        for (index, attachment) in attachments.enumerated() {
            for type in SharedMediaType.allCases {
                if attachment.hasItemConformingToTypeIdentifier(type.toUTTypeIdentifier) {
                    shareLog("Loading attachment index \(index) as \(type)")
                    attachment.loadItem(forTypeIdentifier: type.toUTTypeIdentifier) { [weak self] data, error in
                        guard let self = self, error == nil else {
                            shareLog("ERROR: loadItem failed for index \(index) - \(error?.localizedDescription ?? "unknown error")")
                            DispatchQueue.main.async { self?.dismissWithError() }
                            return
                        }

                        DispatchQueue.main.async {
                            switch type {
                            case .text:
                                if let text = data as? String {
                                    shareLog("Attachment index \(index) is text")
                                    self.handleMedia(forLiteral: text, type: type, index: index, content: content)
                                }
                            case .url:
                                if let url = data as? URL {
                                    shareLog("Attachment index \(index) is URL: \(url)")
                                    self.handleMedia(forLiteral: url.absoluteString, type: type, index: index, content: content)
                                }
                            default:
                                if let url = data as? URL {
                                    shareLog("Attachment index \(index) is file URL: \(url)")
                                    self.handleMedia(forFile: url, type: type, index: index, content: content)
                                } else if let image = data as? UIImage {
                                    shareLog("Attachment index \(index) is UIImage")
                                    self.handleMedia(forUIImage: image, type: type, index: index, content: content)
                                } else {
                                    shareLog("Attachment index \(index) could not be handled for type \(type)")
                                }
                            }
                        }
                    }
                    break
                }
            }
        }
    }

    open override func configurationItems() -> [Any]! { [] }

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

    private func handleMedia(forLiteral item: String, type: SharedMediaType, index: Int, content: NSExtensionItem) {
        sharedMedia.append(SharedMediaFile(
            path: item,
            mimeType: type == .text ? "text/plain" : nil,
            type: type
        ))
        shareLog("Appended literal item (type \(type)) - count now \(sharedMedia.count)")
        if index == (content.attachments?.count ?? 0) - 1, shouldAutoRedirect() {
            saveAndRedirect()
        }
    }

    private func handleMedia(forUIImage image: UIImage, type: SharedMediaType, index: Int, content: NSExtensionItem) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            shareLog("ERROR: containerURL was nil while handling UIImage")
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
        if index == (content.attachments?.count ?? 0) - 1, shouldAutoRedirect() {
            saveAndRedirect()
        }
    }

    private func handleMedia(forFile url: URL, type: SharedMediaType, index: Int, content: NSExtensionItem) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            shareLog("ERROR: containerURL was nil while handling file URL")
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

        if index == (content.attachments?.count ?? 0) - 1, shouldAutoRedirect() {
            saveAndRedirect()
        }
    }

    private func saveAndRedirect(message: String? = nil) {
        let userDefaults = UserDefaults(suiteName: appGroupId)
        userDefaults?.set(toData(data: sharedMedia), forKey: kUserDefaultsKey)
        userDefaults?.set(message, forKey: kUserDefaultsMessageKey)
        userDefaults?.synchronize()
        shareLog("Saved \(sharedMedia.count) item(s) to UserDefaults - redirecting")
        redirectToHostApp()
    }

    private func redirectToHostApp() {
        loadIds()
        guard let redirectURL = URL(string: "\(kSchemePrefix)-\(hostAppBundleIdentifier):share") else {
            shareLog("ERROR: Failed to build redirect URL")
            dismissWithError()
            return
        }

        let minimumDuration: TimeInterval = 3
        let elapsed = loadingShownAt.map { Date().timeIntervalSince($0) } ?? 0
        let delay = max(0, minimumDuration - elapsed)
        shareLog("Redirect scheduled in \(delay) seconds (elapsed: \(elapsed))")

        loadingHideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.loadingHideWorkItem = nil
            DispatchQueue.main.async {
                self.hideLoadingUI()
                self.performRedirect(to: redirectURL)
            }
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

        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        shareLog("Completed extension request")
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
        stack.spacing = 12

        let activity = UIActivityIndicatorView(style: .large)
        activity.startAnimating()

        let label = UILabel()
        label.text = "Importing..."
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = UIColor.label

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cancelButton.addTarget(self, action: #selector(cancelImportTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        stack.addArrangedSubview(activity)
        stack.addArrangedSubview(label)
        stack.translatesAutoresizingMaskIntoConstraints = false

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

    private func hideLoadingUI() {
        loadingHideWorkItem?.cancel()
        loadingHideWorkItem = nil
        loadingView?.removeFromSuperview()
        loadingView = nil
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
        extensionContext?.cancelRequest(withError: error)
    }

    private func clearSharedData() {
        sharedMedia.removeAll()
        if let defaults = UserDefaults(suiteName: appGroupId) {
            defaults.removeObject(forKey: kUserDefaultsKey)
            defaults.removeObject(forKey: kUserDefaultsMessageKey)
            defaults.synchronize()
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


