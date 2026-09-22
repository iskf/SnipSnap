import Cocoa
import Foundation

public struct ReleaseInfo {
    public let version: String
    public let releaseURL: URL
    public let downloadURL: URL
    public let releaseNotes: String?
}

public class AppUpdater: ObservableObject {
    public static let shared = AppUpdater()
    
    @Published public var isChecking: Bool = false
    @Published public var lastCheckedDate: Date? = nil
    
    public var currentVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
    }
    
    public static let repoOwner = "iskf"
    public static let repoName = "SnipSnap"
    public static let releasesURLString = "https://github.com/iskf/SnipSnap/releases"
    public static let latestReleaseRedirectURLString = "https://github.com/iskf/SnipSnap/releases/latest"
    
    private class NoRedirectTaskDelegate: NSObject, URLSessionTaskDelegate {
        var redirectedURL: URL?
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            self.redirectedURL = request.url
            completionHandler(nil) // Intercept redirect without following
        }
    }
    
    private init() {}
    
    // MARK: - Update Check Entry
    
    public func checkForUpdates(userInitiated: Bool = true, completion: ((Result<ReleaseInfo?, Error>) -> Void)? = nil) {
        guard !isChecking else { return }
        
        DispatchQueue.main.async {
            self.isChecking = true
        }
        
        guard let url = URL(string: Self.latestReleaseRedirectURLString) else {
            DispatchQueue.main.async {
                self.isChecking = false
            }
            return
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10.0)
        request.httpMethod = "HEAD"
        request.setValue("SnipSnap-Updater/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        
        let delegate = NoRedirectTaskDelegate()
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        
        let task = session.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self else { return }
            
            defer {
                DispatchQueue.main.async {
                    self.isChecking = false
                    self.lastCheckedDate = Date()
                }
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    completion?(.failure(error))
                    if userInitiated {
                        self.showErrorAlert(error: error)
                    }
                }
                return
            }
            
            // Extract redirected tag from Location or task delegate
            var targetURL = delegate.redirectedURL
            if targetURL == nil, let http = response as? HTTPURLResponse {
                if let loc = http.value(forHTTPHeaderField: "Location") ?? (http.allHeaderFields["Location"] as? String) ?? (http.allHeaderFields["location"] as? String) {
                    targetURL = URL(string: loc)
                }
            }
            
            guard let finalURL = targetURL else {
                let err = NSError(domain: "AppUpdater", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析最新版本信息"])
                DispatchQueue.main.async {
                    completion?(.failure(err))
                    if userInitiated {
                        self.showErrorAlert(error: err)
                    }
                }
                return
            }
            
            let tag = finalURL.lastPathComponent // e.g. "v1.1.0"
            let latestVersion = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let cleanCurrent = self.currentVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            
            let downloadURL = URL(string: "https://github.com/\(Self.repoOwner)/\(Self.repoName)/releases/download/\(tag)/SnipSnap-\(latestVersion).dmg")
                ?? finalURL
            
            let info = ReleaseInfo(
                version: latestVersion,
                releaseURL: finalURL,
                downloadURL: downloadURL,
                releaseNotes: nil
            )
            
            let comparison = self.compareVersions(cleanCurrent, latestVersion)
            let hasUpdate = (comparison == .orderedAscending)
            
            DispatchQueue.main.async {
                if hasUpdate {
                    completion?(.success(info))
                    if userInitiated {
                        self.showUpdateAvailableAlert(info: info)
                    }
                } else {
                    completion?(.success(nil))
                    if userInitiated {
                        self.showUpToDateAlert()
                    }
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Semantic Version Comparison
    
    public func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let clean1 = v1.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).components(separatedBy: ".")
        let clean2 = v2.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).components(separatedBy: ".")
        let maxCount = max(clean1.count, clean2.count)
        for i in 0..<maxCount {
            let n1 = i < clean1.count ? (Int(clean1[i]) ?? 0) : 0
            let n2 = i < clean2.count ? (Int(clean2[i]) ?? 0) : 0
            if n1 < n2 { return .orderedAscending }
            if n1 > n2 { return .orderedDescending }
        }
        return .orderedSame
    }
    
    // MARK: - User Interface Alerts
    
    private func showUpdateAvailableAlert(info: ReleaseInfo) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = String(format: L10n("update.title.new_version"), info.version)
        alert.informativeText = String(
            format: L10n("update.msg.new_version"),
            currentVersion,
            info.version
        )
        alert.alertStyle = .informational
        
        let downloadBtn = alert.addButton(withTitle: L10n("update.btn.download"))
        let laterBtn = alert.addButton(withTitle: L10n("update.btn.later"))
        
        downloadBtn.keyEquivalent = "\r"
        laterBtn.keyEquivalent = "\u{1b}"
        
        if let icon = NSApp.applicationIconImage {
            alert.icon = icon
        }
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(info.releaseURL)
        }
    }
    
    private func showUpToDateAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L10n("update.title.up_to_date")
        alert.informativeText = String(format: L10n("update.msg.up_to_date"), currentVersion)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n("update.btn.ok"))
        if let icon = NSApp.applicationIconImage {
            alert.icon = icon
        }
        alert.runModal()
    }
    
    private func showErrorAlert(error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L10n("update.title.failed")
        alert.informativeText = String(format: L10n("update.msg.failed"), error.localizedDescription)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n("update.btn.ok"))
        if let icon = NSApp.applicationIconImage {
            alert.icon = icon
        }
        alert.runModal()
    }
}
