//
//  ShareViewController.swift
//  MangosicShareExtension
//
//  Created by Tri on 15/1/26.
//

import UIKit
import UniformTypeIdentifiers

/// Share Extension to receive YouTube URLs from other apps
class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
        handleSharedContent()
    }
    
    /// Process the shared content (YouTube URL)
    private func handleSharedContent() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeAndDismiss()
            return
        }
        
        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            
            for attachment in attachments {
                // Handle URL type (when sharing from YouTube app)
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] data, error in
                        DispatchQueue.main.async {
                            if let url = data as? URL {
                                self?.processURL(url)
                            } else if let urlString = data as? String, let url = URL(string: urlString) {
                                self?.processURL(url)
                            } else {
                                self?.completeAndDismiss()
                            }
                        }
                    }
                    return
                }
                
                // Handle plain text (some apps share as text)
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] data, error in
                        DispatchQueue.main.async {
                            if let text = data as? String {
                                if let url = self?.extractURLFromText(text) {
                                    self?.processURL(url)
                                } else {
                                    self?.completeAndDismiss()
                                }
                            } else {
                                self?.completeAndDismiss()
                            }
                        }
                    }
                    return
                }
            }
        }
        
        completeAndDismiss()
    }
    
    /// Extract URL from shared text
    private func extractURLFromText(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true {
            return url
        }
        
        let patterns = [
            "https?://(?:www\\.)?youtube\\.com/watch\\?[^\\s]+",
            "https?://youtu\\.be/[a-zA-Z0-9_-]+",
            "https?://(?:www\\.)?youtube\\.com/shorts/[a-zA-Z0-9_-]+",
            "https?://music\\.youtube\\.com/watch\\?[^\\s]+"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                return URL(string: String(text[range]))
            }
        }
        
        return nil
    }
    
    /// Process URL and open main app
    private func processURL(_ url: URL) {
        guard let videoID = extractVideoID(from: url) else {
            completeAndDismiss()
            return
        }
        
        openMainApp(with: videoID)
    }
    
    /// Extract YouTube video ID from various URL formats
    private func extractVideoID(from url: URL) -> String? {
        let urlString = url.absoluteString
        
        // youtube.com/watch?v=VIDEO_ID or music.youtube.com/watch?v=VIDEO_ID
        if urlString.contains("youtube.com/watch") || urlString.contains("music.youtube.com/watch") {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let videoID = components?.queryItems?.first(where: { $0.name == "v" })?.value {
                return videoID
            }
        }
        
        // youtu.be/VIDEO_ID
        if url.host == "youtu.be" {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            if let videoID = pathComponents.first, !videoID.isEmpty {
                return videoID
            }
        }
        
        // youtube.com/v/VIDEO_ID, /embed/VIDEO_ID, /shorts/VIDEO_ID
        for pattern in ["/v/", "/embed/", "/shorts/"] {
            if urlString.contains(pattern) {
                let pathComponents = url.pathComponents.filter { $0 != "/" }
                if let videoID = pathComponents.last, !videoID.isEmpty {
                    return videoID
                }
            }
        }
        
        return nil
    }
    
    /// Open the main Mangosic app with the video ID
    private func openMainApp(with videoID: String) {
        guard let appURL = URL(string: "mangosic://play?v=\(videoID)") else {
            completeAndDismiss()
            return
        }
        
        // Use the private API workaround to open URL from extension
        // This works by finding UIApplication through the responder chain
        openURL(appURL)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.completeAndDismiss()
        }
    }
    
    /// Open URL using private API workaround
    @discardableResult
    private func openURL(_ url: URL) -> Bool {
        // Method: Use UIApplication.shared via dynamic lookup
        guard let application = UIApplication.value(forKeyPath: #keyPath(UIApplication.shared)) as? UIApplication else {
            return false
        }
        
        if application.canOpenURL(url) {
            application.open(url, options: [:], completionHandler: nil)
            return true
        }
        
        return false
    }
    
    /// Complete the extension request
    private func completeAndDismiss() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
