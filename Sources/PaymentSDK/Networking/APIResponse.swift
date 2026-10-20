import Foundation

enum NextActionCode {
    static let phone = 2
    static let pin = 3
    static let stop = 7
    static let openContent = 31
}

/// Response body shared by all three actions. Decoding is lenient: only `Error` is required,
/// nested objects that fail to decode become `nil`, and IDs may arrive as strings or numbers.
struct APIResponse: Decodable, Sendable {
    let error: Int
    let messageToShow: String?
    let sessionID: String?
    let scheme: String?
    let themeID: String?
    let signupMethod: [String]?
    let nextAction: NextAction?

    enum CodingKeys: String, CodingKey {
        case error = "Error"
        case messageToShow = "MessageToShow"
        case sessionID = "SessionID"
        case scheme = "Scheme"
        case themeID = "ThemeID"
        case signupMethod = "SignupMethod"
        case nextAction = "NextAction"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let value = c.flexibleInt(.error) {
            error = value
        } else {
            throw DecodingError.keyNotFound(CodingKeys.error, .init(codingPath: c.codingPath,
                                                                    debugDescription: "Missing or invalid Error"))
        }
        messageToShow = c.lenient(String.self, .messageToShow)
        sessionID = c.flexibleString(.sessionID)
        scheme = c.lenient(String.self, .scheme)
        themeID = c.flexibleString(.themeID)
        signupMethod = c.lenient([String].self, .signupMethod)
        nextAction = c.lenient(NextAction.self, .nextAction)
    }

    var isSuccess: Bool { error == 0 || error == 3 }
    var isAlreadySubscribed: Bool { error == 3 }

    /// `MessageToShow` trimmed; `nil` when empty.
    var message: String? { messageToShow?.nonEmptyTrimmed }

    /// Theme ID from `NextAction.Info.Theme.ThemeID`, falling back to the top-level `ThemeID`.
    var resolvedThemeID: String? {
        nextAction?.info?.theme?.themeID?.nonEmptyTrimmed ?? themeID?.nonEmptyTrimmed
    }
}

struct NextAction: Decodable, Sendable {
    let action: Int?
    let title: Title?
    let info: Info?

    enum CodingKeys: String, CodingKey {
        case action = "Action"
        case title = "Title"
        case info = "Info"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        action = c.flexibleInt(.action)
        title = c.lenient(Title.self, .title)
        info = c.lenient(Info.self, .info)
    }

    struct Title: Decodable, Sendable {
        let name: String?
        let headerPic: String?

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case headerPic = "HeaderPic"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = c.lenient(String.self, .name)
            headerPic = c.lenient(String.self, .headerPic)
        }
    }

    struct Info: Decodable, Sendable {
        let generalSettings: GeneralSettings?
        let disclaimers: Disclaimers?
        let theme: ThemeInfo?

        enum CodingKeys: String, CodingKey {
            case generalSettings = "GeneralSettings"
            case disclaimers = "Disclaimers"
            case theme = "Theme"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            generalSettings = c.lenient(GeneralSettings.self, .generalSettings)
            disclaimers = c.lenient(Disclaimers.self, .disclaimers)
            theme = c.lenient(ThemeInfo.self, .theme)
        }
    }
}

struct GeneralSettings: Decodable, Sendable {
    let country: Country?
    let supportedLanguages: [String]?

    enum CodingKeys: String, CodingKey {
        case country = "Country"
        case supportedLanguages = "SupportedLanguages"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        country = c.lenient(Country.self, .country)
        supportedLanguages = c.lenient([String].self, .supportedLanguages)
    }

    struct Country: Decodable, Sendable {
        /// ISO code, e.g. `"LB"`.
        let name: String?
        /// Dial code without `+`, e.g. `"961"`.
        let code: String?

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case code = "Code"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = c.flexibleString(.name)
            code = c.flexibleString(.code)
        }
    }
}

/// Form-URL-encoded HTML snippets. Use `HTMLDisclaimer.formURLDecode` before rendering.
struct Disclaimers: Decodable, Sendable {
    let headerInfo: String?
    let middleInfo: String?
    let footerInfo: String?
    let otpTopHeaderInfo: String?

    enum CodingKeys: String, CodingKey {
        case headerInfo, middleInfo, footerInfo
        case otpTopHeaderInfo = "OTPTopHeaderInfo"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        headerInfo = c.lenient(String.self, .headerInfo)
        middleInfo = c.lenient(String.self, .middleInfo)
        footerInfo = c.lenient(String.self, .footerInfo)
        otpTopHeaderInfo = c.lenient(String.self, .otpTopHeaderInfo)
    }
}

/// `NextAction.Info.Theme`: labels and settings for the phone and PIN screens.
struct ThemeInfo: Decodable, Sendable {
    let themeID: String?
    let textBox: TextBox?
    let button: Label?
    let wrongNumber: Label?
    let askCodeAgain: AskCodeAgain?
    let termsAndConditions: LegalContent?
    let privacyPolicies: LegalContent?

    enum CodingKeys: String, CodingKey {
        case themeID = "ThemeID"
        case textBox = "TextBox"
        case button = "Button"
        case wrongNumber = "WrongNumber"
        case askCodeAgain = "AskCodeAgain"
        case termsAndConditions = "TermsAndConditions"
        case privacyPolicies = "PrivacyPolicies"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        themeID = c.flexibleString(.themeID)
        textBox = c.lenient(TextBox.self, .textBox)
        button = c.lenient(Label.self, .button)
        wrongNumber = c.lenient(Label.self, .wrongNumber)
        askCodeAgain = c.lenient(AskCodeAgain.self, .askCodeAgain)
        termsAndConditions = c.lenient(LegalContent.self, .termsAndConditions)
        privacyPolicies = c.lenient(LegalContent.self, .privacyPolicies)
    }

    struct Label: Decodable, Sendable {
        let text: String?
        enum CodingKeys: String, CodingKey { case text = "Text" }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            text = c.lenient(String.self, .text)
        }
    }

    /// Resend PIN. Decoded but not shown yet.
    struct AskCodeAgain: Decodable, Sendable {
        let text: String?
        let countDown: Int?

        enum CodingKeys: String, CodingKey {
            case text = "Text"
            case countDown = "CountDown"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            text = c.lenient(String.self, .text)
            countDown = c.flexibleInt(.countDown)
        }
    }

    struct LegalContent: Decodable, Sendable {
        let text: String?
        /// HTML.
        let content: String?

        enum CodingKeys: String, CodingKey {
            case text = "Text"
            case content = "Content"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            text = c.lenient(String.self, .text)
            content = c.lenient(String.self, .content)
        }
    }

    struct TextBox: Decodable, Sendable {
        let text: String?
        let errorMSG: String?
        let length: Int?
        let pinLength: [Int]?
        let isNumeric: Int?

        enum CodingKeys: String, CodingKey {
            case text = "Text"
            case errorMSG = "ErrorMSG"
            case length = "Length"
            case pinLength = "PinLength"
            case isNumeric = "isNumeric"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            text = c.lenient(String.self, .text)
            errorMSG = c.lenient(String.self, .errorMSG)
            length = c.flexibleInt(.length)
            pinLength = c.lenient([Int].self, .pinLength)
            if let bool = c.lenient(Bool.self, .isNumeric) {
                isNumeric = bool ? 1 : 0
            } else {
                isNumeric = c.flexibleInt(.isNumeric)
            }
        }

        /// `Length`, else `PinLength[0]`, else 6.
        var effectivePinLength: Int {
            if let length, length > 0 { return length }
            if let first = pinLength?.first, first > 0 { return first }
            return 6
        }

        /// Numeric keyboard unless the backend explicitly sends `isNumeric: 0`.
        var usesNumericKeyboard: Bool { (isNumeric ?? 1) != 0 }
    }
}

// MARK: - Lenient decoding helpers

extension KeyedDecodingContainer {
    /// Decodes the value, returning `nil` when the key is missing, null, or the wrong type.
    func lenient<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }

    /// Accepts `"299"` or `299`.
    func flexibleString(_ key: Key) -> String? {
        if let string = lenient(String.self, key) { return string }
        if let int = lenient(Int.self, key) { return String(int) }
        if let double = lenient(Double.self, key) {
            return double.rounded() == double ? String(Int(double)) : String(double)
        }
        return nil
    }

    /// Accepts `3` or `"3"`.
    func flexibleInt(_ key: Key) -> Int? {
        if let int = lenient(Int.self, key) { return int }
        if let string = lenient(String.self, key) {
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
