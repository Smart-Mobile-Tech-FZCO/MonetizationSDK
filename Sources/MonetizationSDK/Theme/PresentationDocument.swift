import Foundation

/// Which shell wraps the phone and PIN screens.
enum PresentationTemplate: String, Equatable, Sendable {
    /// Straight to the phone screen.
    case single
    /// Several intro pages, then the phone screen.
    case onboarding
    /// One full-screen page with a delayed close button, then the phone screen.
    case interstitial
}

/// A resolved theme file: its shell template, intro pages and visual tokens.
struct PresentationDocument: Equatable, Sendable {
    /// Bundle file name this document came from (`"644"`, `"default-theme"`), or `"fallback"`.
    var sourceName: String
    var template: PresentationTemplate
    var pages: [PresentationPage]
    /// Seconds before the interstitial close button appears. `0` shows it immediately.
    var closeDelay: Int
    var theme: ThemeTokens

    var hasIntro: Bool { template != .single && !pages.isEmpty }

    /// Parses a theme file. Returns `nil` when tokens are invalid or `template` is unknown.
    static func decode(_ data: Data, sourceName: String) -> PresentationDocument? {
        guard let theme = try? JSONDecoder().decode(ThemeTokens.self, from: data),
              let shell = try? JSONDecoder().decode(ShellFields.self, from: data) else { return nil }

        let template: PresentationTemplate
        if let raw = shell.template {
            guard let known = PresentationTemplate(rawValue: raw) else { return nil }
            template = known
        } else {
            template = .single
        }

        return PresentationDocument(
            sourceName: sourceName,
            template: template,
            pages: shell.pages,
            closeDelay: max(0, shell.closeDelay),
            theme: theme
        )
    }

    private struct ShellFields: Decodable {
        let template: String?
        let pages: [PresentationPage]
        let closeDelay: Int

        enum CodingKeys: String, CodingKey { case template, pages, closeDelay }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // A non-string template is invalid, not "missing".
            if c.contains(.template), !((try? c.decodeNil(forKey: .template)) ?? false) {
                template = try c.decode(String.self, forKey: .template)
            } else {
                template = nil
            }
            pages = (c.lenient([Failable<PresentationPage>].self, .pages) ?? []).compactMap(\.value)
            if let int = c.flexibleInt(.closeDelay) {
                closeDelay = int
            } else {
                closeDelay = Int(c.lenient(Double.self, .closeDelay) ?? 0)
            }
        }
    }
}

struct PresentationPage: Decodable, Equatable, Sendable {
    let imageUrl: String?
    let images: [String]
    let title: LocalizedText?
    let subtitle: LocalizedText?
    let text: LocalizedText?
    let points: [LocalizedText]
    let button: LocalizedText?

    enum CodingKeys: String, CodingKey { case imageUrl, images, title, subtitle, text, points, button }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        imageUrl = c.lenient(String.self, .imageUrl)
        images = (c.lenient([String].self, .images) ?? []).compactMap(\.nonEmptyTrimmed)
        title = c.lenient(LocalizedText.self, .title)
        subtitle = c.lenient(LocalizedText.self, .subtitle)
        text = c.lenient(LocalizedText.self, .text)
        points = (c.lenient([Failable<LocalizedText>].self, .points) ?? []).compactMap(\.value)
        button = c.lenient(LocalizedText.self, .button)
    }

    func buttonTitle(_ language: String) -> String {
        button?.resolve(language).nonEmptyTrimmed ?? L10n.text(.next, language)
    }
}
