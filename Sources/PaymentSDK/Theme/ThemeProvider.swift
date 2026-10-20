import Foundation

/// Turns a backend theme ID into a presentation. Async so a provider that downloads
/// themes from the backend can replace the bundled one without changing the flow.
protocol ThemeProviding: Sendable {
    func document(forThemeID themeID: String?) async -> PresentationDocument
}

/// Looks up `<id>.json` in the SDK bundle, then `default-theme.json`, then hard-coded tokens.
/// With `forcedThemeID`, that theme replaces whatever ID the backend sends.
struct BundledThemeProvider: ThemeProviding {
    static let defaultName = "default-theme"

    let forcedThemeID: String?
    let loadData: @Sendable (String) -> Data?

    init(forcedThemeID: String? = nil,
         loadData: @escaping @Sendable (String) -> Data? = BundledThemeProvider.loadFromModuleBundle) {
        self.forcedThemeID = forcedThemeID
        self.loadData = loadData
    }

    func document(forThemeID themeID: String?) async -> PresentationDocument {
        resolve(themeID: themeID)
    }

    func resolve(themeID: String?) -> PresentationDocument {
        if let name = Self.fileName(for: forcedThemeID ?? themeID),
           let data = loadData(name),
           let document = PresentationDocument.decode(data, sourceName: name) {
            return document
        }
        if let data = loadData(Self.defaultName),
           let document = PresentationDocument.decode(data, sourceName: Self.defaultName) {
            return document
        }
        return .hardcodedFallback
    }

    /// Only plain IDs map to a file name; paths and extensions are rejected.
    static func fileName(for themeID: String?) -> String? {
        guard let id = themeID?.nonEmptyTrimmed,
              id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else { return nil }
        return id
    }

    @Sendable static func loadFromModuleBundle(_ name: String) -> Data? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else { return nil }
        return try? Data(contentsOf: url)
    }
}

extension PresentationDocument {
    /// Used only when `default-theme.json` is missing or invalid. Mirrors that file.
    static let hardcodedFallback: PresentationDocument = {
        let json = """
        {
          "themeId": "fallback", "version": 1,
          "screen": { "background": { "type": "color", "color": "#F2F2F7" },
                      "contentMaxWidth": 520, "horizontalPadding": 24, "fontFamily": "system", "statusBar": "dark" },
          "header": { "style": "none", "logoMaxHeight": 100, "logoFallbackHeight": 72, "bottomCornerRadius": 0,
                      "titleColor": "#000000", "languageColor": "#0A84FF", "closeColor": "#8E8E93" },
          "field": { "height": 52, "background": "#FFFFFF", "borderColor": "#0A84FF", "borderWidth": 1,
                     "borderOpacity": 0.5, "cornerRadius": 8, "textColor": "#000000", "placeholderColor": "#8E8E93",
                     "fontSize": 17, "marginTop": 8, "dialCodeColor": "#0A84FF", "otpBoxBackground": "#FFFFFF",
                     "otpBoxBorderColor": "#8E8E93", "otpFocusBorderColor": "#0A84FF" },
          "button": { "height": 52, "cornerRadius": 10, "fontSize": 17, "fontWeight": "semibold",
                      "textTransform": "none", "textColor": "#FFFFFF", "disabledBackground": "#AEAEB2",
                      "background": { "type": "solid", "color": "#0A84FF", "colors": [] } },
          "text": {
            "disclaimer": { "color": "#8E8E93", "fontSize": 13, "lineHeight": 1.4, "alignment": "center" },
            "legal": { "color": "#0A84FF", "fontSize": 12, "lineHeight": 1.4, "alignment": "center" },
            "error": { "color": "#FFFFFF", "background": "#E53935", "fontSize": 13, "cornerRadius": 12 },
            "serviceDescription": { "color": "#3C3C43", "fontSize": 14, "lineHeight": 1.6, "alignment": "center" }
          },
          "spacing": { "top": 8, "afterLogo": 8, "afterField": 8, "afterButton": 8, "componentGap": 10 },
          "blocks": []
        }
        """
        return PresentationDocument.decode(Data(json.utf8), sourceName: "fallback")!
    }()
}
