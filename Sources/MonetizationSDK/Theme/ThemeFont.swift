import CoreText
import SwiftUI
import UIKit

/// Resolves a theme's `fontFamily`. Uses the family when it is installed or was registered
/// from `fontUrl`, otherwise the system font.
enum ThemeFont {
    /// Lock-protected bookkeeping shared across threads.
    private final class Registry: @unchecked Sendable {
        let lock = NSLock()
        var registeredFamilies: Set<String> = []
        var attemptedURLs: Set<String> = []

        func sync<T>(_ body: (Registry) -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return body(self)
        }
    }

    private static let registry = Registry()

    static func font(family: String?, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        guard let family, isAvailable(family) else { return .system(size: size, weight: weight) }
        return Font.custom(family, size: size).weight(weight)
    }

    static func isAvailable(_ family: String) -> Bool {
        let trimmed = family.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "system" else { return false }
        let registered = registry.sync { $0.registeredFamilies.contains(trimmed) }
        return registered || !UIFont.fontNames(forFamilyName: trimmed).isEmpty
    }

    /// Downloads and registers the theme's font once. Accepts a font file URL or a
    /// Google-Fonts-style CSS URL. Failures are ignored: the system font is used instead.
    static func loadIfNeeded(family: String, from urlString: String?) async {
        guard let urlString = urlString?.nonEmptyTrimmed, let url = URL(string: urlString),
              !isAvailable(family) else { return }
        let isNew = registry.sync { $0.attemptedURLs.insert(urlString).inserted }
        guard isNew else { return }

        var fontURLs = [url]
        if url.pathExtension.isEmpty || url.pathExtension.lowercased() == "css" || url.path.contains("css") {
            guard let data = await fetch(url), let css = String(data: data, encoding: .utf8) else { return }
            fontURLs = fontFileURLs(inCSS: css)
        }

        var registeredAny = false
        for fontURL in fontURLs {
            guard let data = await fetch(fontURL),
                  let provider = CGDataProvider(data: data as CFData),
                  let cgFont = CGFont(provider) else { continue }
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterGraphicsFont(cgFont, &error) {
                registeredAny = true
            } else if !UIFont.fontNames(forFamilyName: family).isEmpty {
                registeredAny = true // already registered by someone else
            }
        }
        if registeredAny {
            let name = family.trimmingCharacters(in: .whitespacesAndNewlines)
            registry.sync { _ = $0.registeredFamilies.insert(name) }
        }
    }

    /// Picks the regular (400), medium (500), semibold (600) and bold (700) faces from `@font-face`
    /// rules, or the first face when no weights are declared.
    static func fontFileURLs(inCSS css: String) -> [URL] {
        guard let faceRegex = try? NSRegularExpression(pattern: "@font-face\\s*\\{([^}]*)\\}"),
              let urlRegex = try? NSRegularExpression(pattern: "url\\(\\s*['\"]?([^'\")]+)['\"]?\\s*\\)"),
              let weightRegex = try? NSRegularExpression(pattern: "font-weight\\s*:\\s*(\\d+)") else { return [] }
        let ns = css as NSString
        var byWeight: [Int: URL] = [:]
        var first: URL?
        for face in faceRegex.matches(in: css, range: NSRange(location: 0, length: ns.length)) {
            let body = ns.substring(with: face.range(at: 1))
            let bodyNS = body as NSString
            guard let urlMatch = urlRegex.firstMatch(in: body, range: NSRange(location: 0, length: bodyNS.length)),
                  let url = URL(string: bodyNS.substring(with: urlMatch.range(at: 1))) else { continue }
            if first == nil { first = url }
            if let w = weightRegex.firstMatch(in: body, range: NSRange(location: 0, length: bodyNS.length)),
               let weight = Int(bodyNS.substring(with: w.range(at: 1))), byWeight[weight] == nil {
                byWeight[weight] = url
            }
        }
        let wanted = [400, 500, 600, 700].compactMap { byWeight[$0] }
        if !wanted.isEmpty { return wanted }
        return first.map { [$0] } ?? []
    }

    private static func fetch(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent") // Google Fonts then serves TTF
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse).map({ (200...299).contains($0.statusCode) }) ?? true else { return nil }
        return data
    }
}

extension ThemeTokens {
    var fontFamily: String? {
        let family = screen.fontFamily.trimmingCharacters(in: .whitespacesAndNewlines)
        return family.isEmpty || family.lowercased() == "system" ? nil : family
    }

    func font(size: Double, weight: Font.Weight = .regular) -> Font {
        ThemeFont.font(family: fontFamily, size: size, weight: weight)
    }

    var buttonFontWeight: Font.Weight {
        switch button.fontWeight {
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        default: return .regular
        }
    }
}
