import Foundation

/// Visual tokens from a bundled theme JSON (`default-theme.json`, `625.json`, ...).
/// Core sections are required; anything added later (form card, floating label, blocks) is optional.
struct ThemeTokens: Decodable, Equatable, Sendable {
    let themeId: String
    let version: Int
    let screen: Screen
    let header: Header
    let field: Field
    let button: Button
    let text: TextStyles
    let spacing: Spacing
    let formCard: FormCard?
    let blocks: [ThemeBlock]

    enum CodingKeys: String, CodingKey {
        case themeId, version, screen, header, field, button, text, spacing, formCard, blocks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        themeId = c.flexibleString(.themeId) ?? ""
        version = c.flexibleInt(.version) ?? 1
        screen = try c.decode(Screen.self, forKey: .screen)
        header = try c.decode(Header.self, forKey: .header)
        field = try c.decode(Field.self, forKey: .field)
        button = try c.decode(Button.self, forKey: .button)
        text = try c.decode(TextStyles.self, forKey: .text)
        spacing = try c.decode(Spacing.self, forKey: .spacing)
        formCard = c.lenient(FormCard.self, .formCard)
        // One malformed block must not invalidate the whole theme.
        blocks = (c.lenient([Failable<ThemeBlock>].self, .blocks) ?? []).compactMap(\.value)
    }

    struct Screen: Decodable, Equatable, Sendable {
        let background: Fill
        let contentMaxWidth: Double
        let horizontalPadding: Double
        let fontFamily: String
        let fontUrl: String?
        let statusBar: String

        var usesLightStatusBar: Bool { statusBar == "light" }
    }

    struct Header: Decodable, Equatable, Sendable {
        let style: String
        let logoMaxHeight: Double
        let logoFallbackHeight: Double
        let titleColor: String
        let languageColor: String
        let closeColor: String
        let backgroundColor: String?
        let imageUrl: String?
        let logoUrl: String?
        let logoAspectRatio: Double?
        let aspectRatio: Double?
        let bottomCornerRadius: Double?

        var showsBanner: Bool {
            style == "image" || style == "color" || !(imageUrl ?? "").isEmpty
        }
    }

    struct Field: Decodable, Equatable, Sendable {
        let height: Double
        let background: String
        let borderColor: String
        let borderWidth: Double
        let borderOpacity: Double
        let cornerRadius: Double
        let textColor: String
        let placeholderColor: String
        let fontSize: Double
        let marginTop: Double
        let dialCodeColor: String
        let otpBoxBackground: String
        let otpBoxBorderColor: String
        let otpFocusBorderColor: String
        let floatingLabel: FloatingLabel?
        let placeholderText: PlaceholderText?
        let icons: Icons?

        struct FloatingLabel: Decodable, Equatable, Sendable {
            let color: String
            let background: String?
            let fontSize: Double?
            let cornerRadius: Double?
            let phoneText: LocalizedText?
            let pinText: LocalizedText?
        }

        struct PlaceholderText: Decodable, Equatable, Sendable {
            let phone: String?
            let pin: String?
        }

        struct Icons: Decodable, Equatable, Sendable {
            let phoneColor: String?
            let phoneActiveColor: String?
            let checkColor: String?
            let checkValidColor: String?
        }
    }

    struct Button: Decodable, Equatable, Sendable {
        let height: Double
        let cornerRadius: Double
        let fontSize: Double
        let fontWeight: String
        let textTransform: String
        let textColor: String
        let disabledBackground: String
        let background: Fill

        func title(_ raw: String) -> String {
            switch textTransform {
            case "uppercase": return raw.uppercased()
            case "lowercase": return raw.lowercased()
            default: return raw
            }
        }
    }

    struct TextStyle: Decodable, Equatable, Sendable {
        let color: String
        let fontSize: Double
        let lineHeight: Double?
        let alignment: String?
        let background: String?
        let cornerRadius: Double?
    }

    struct TextStyles: Decodable, Equatable, Sendable {
        let disclaimer: TextStyle
        let legal: TextStyle
        let error: TextStyle
        let serviceDescription: TextStyle
    }

    struct Spacing: Decodable, Equatable, Sendable {
        let top: Double
        let afterLogo: Double
        let afterField: Double
        let afterButton: Double
        let componentGap: Double
    }

    /// `type`: `color` | `image` | `video` (screen) or `solid` | `linear` | `radial` (button).
    struct Fill: Decodable, Equatable, Sendable {
        let type: String
        let color: String?
        let colors: [String]?
        let url: String?
        let overlay: String?

        var gradientColors: [String] { (colors ?? []).filter { !$0.isEmpty } }
    }

    struct FormCard: Decodable, Equatable, Sendable {
        let background: String
        let borderColor: String?
        let borderWidth: Double?
        let cornerRadius: Double?
        let padding: Double?
        let marginTop: Double?
        let shadowColor: String?
        let shadowRadius: Double?
        let shadowY: Double?
    }
}

// MARK: - Blocks

/// Extra content below or around the form, e.g. FAQ, image grid, carousel.
struct ThemeBlock: Decodable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case link, imageCarousel, cardGrid, logoRow, faq, imageGrid
    }

    enum Placement: String, Sendable {
        case beforeForm
        case afterMiddleDisclaimer
        case afterForm
    }

    let id: String
    let kind: Kind
    let placement: Placement
    let columns: Int?
    let intervalSeconds: Double?
    let condition: Condition?
    let title: LocalizedText?
    let style: Style
    let items: [Item]

    enum CodingKeys: String, CodingKey {
        case id, type, placement, columns, intervalSeconds, condition, title, style, items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = try c.decode(String.self, forKey: .type)
        guard let kind = Kind(rawValue: rawType) else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown block type \(rawType)")
        }
        self.kind = kind
        id = c.flexibleString(.id) ?? rawType
        placement = c.lenient(String.self, .placement).flatMap(Placement.init(rawValue:)) ?? .afterForm
        columns = c.flexibleInt(.columns)
        intervalSeconds = c.lenient(Double.self, .intervalSeconds)
        condition = c.lenient(Condition.self, .condition)
        title = c.lenient(LocalizedText.self, .title)
        style = c.lenient(Style.self, .style) ?? Style()
        items = (c.lenient([Failable<Item>].self, .items) ?? []).compactMap(\.value)
    }

    struct Condition: Decodable, Equatable, Sendable {
        let serviceIds: [String]?
        let country: String?

        /// The API does not send a service ID, so a block restricted to service IDs is hidden.
        func matches(countryISO: String?) -> Bool {
            if let ids = serviceIds, !ids.isEmpty { return false }
            if let required = country?.nonEmptyTrimmed {
                return required.caseInsensitiveCompare(countryISO ?? "") == .orderedSame
            }
            return true
        }
    }

    struct Style: Decodable, Equatable, Sendable {
        var color: String?
        var fontSize: Double?
        var aspectRatio: Double?
        var cornerRadius: Double?
        var marginTop: Double?
        var contentMode: String?
        var shadowColor: String?
        var cardCornerRadius: Double?
        var cardMinHeight: Double?
        var cardOverlayColors: [String]?
        var iconBackgroundColors: [String]?
        var iconColor: String?
        var titleColor: String?
        var titleFontSize: Double?
        var textColor: String?
        var textFontSize: Double?
        var gap: Double?
        var logoWidth: Double?
        var logoAspectRatio: Double?
        var itemBackground: String?
        var itemBorderColor: String?
        var itemCornerRadius: Double?
        var itemAspectRatio: Double?
        var questionColor: String?
        var questionFontSize: Double?
        var answerColor: String?
        var answerFontSize: Double?
    }

    struct Item: Decodable, Equatable, Sendable {
        let icon: String?
        let title: LocalizedText?
        let text: LocalizedText?
        let label: LocalizedText?
        let question: LocalizedText?
        let answer: LocalizedText?
        /// A plain URL string or a per-language map.
        let imageUrl: LocalizedText?
        let url: String?
    }
}

/// Copy that is either a plain string or `{ "en": ..., "ar": ... }`.
struct LocalizedText: Decodable, Equatable, Sendable {
    let values: [String: String]

    init(_ values: [String: String]) { self.values = values }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let string = try? c.decode(String.self) {
            values = ["": string]
        } else {
            values = try c.decode([String: String].self)
        }
    }

    /// The requested language, then English, then any value.
    func resolve(_ language: String) -> String {
        let candidates = [values[language.lowercased()], values["en"], values[""]]
        if let hit = candidates.compactMap({ $0?.nonEmptyTrimmed }).first { return hit }
        return values.values.compactMap(\.nonEmptyTrimmed).sorted().first ?? ""
    }
}

/// Decodes `T`, or `nil` if this element is malformed.
struct Failable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}
