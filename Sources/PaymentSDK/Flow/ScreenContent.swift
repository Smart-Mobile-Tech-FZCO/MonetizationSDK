import Foundation

/// Terms & Conditions or Privacy Policy: a tappable label that opens `html` in a sheet.
struct LegalLink: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let html: String
}

struct PhoneScreenContent: Equatable, Sendable {
    var headerPicURL: URL?
    var serviceName: String?
    var headerHTML: String?
    var middleHTML: String?
    var footerHTML: String?
    var placeholder: String
    var buttonTitle: String
    /// Dial code digits (`"961"`) when the backend locks the country.
    var lockedDialCode: String?
    var countryISO: String?
    /// `TextBox.ErrorMSG`, shown when local validation fails.
    var validationMessage: String?
    var legalLinks: [LegalLink]
}

struct PinScreenContent: Equatable, Sendable {
    var headerPicURL: URL?
    var serviceName: String?
    var otpTopHTML: String?
    var headerHTML: String?
    var middleHTML: String?
    var footerHTML: String?
    var pinLength: Int
    var usesNumericKeyboard: Bool
    var buttonTitle: String
    var wrongNumberTitle: String?
    /// `TextBox.ErrorMSG`, shown when the PIN is incomplete.
    var validationMessage: String?
    var legalLinks: [LegalLink]
    /// Resend PIN (`AskCodeAgain`). Kept for later; not shown yet.
    var resendTitle: String?
    var resendCountdown: Int?
}

/// Values learned earlier in the session that later responses may omit
/// (sendPin's response has no `GeneralSettings` or legal links).
struct SessionContext: Equatable, Sendable {
    var lockedDialCode: String?
    var countryISO: String?
    var headerPicURL: URL?
    var serviceName: String?
    var legalLinks: [LegalLink] = []

    mutating func absorb(_ response: APIResponse) {
        let next = response.nextAction
        if let code = next?.info?.generalSettings?.country?.code?.filter(\.isNumber), !code.isEmpty {
            lockedDialCode = code
        }
        if let iso = next?.info?.generalSettings?.country?.name?.nonEmptyTrimmed {
            countryISO = iso.uppercased()
        }
        if let url = ScreenContentMapper.httpURL(next?.title?.headerPic) {
            headerPicURL = url
        }
        if let name = next?.title?.name?.nonEmptyTrimmed {
            serviceName = name
        }
        let links = ScreenContentMapper.legalLinks(next?.info?.theme)
        if !links.isEmpty { legalLinks = links }
    }
}

enum ScreenContentMapper {
    static func phone(from response: APIResponse, context: SessionContext, language: String) -> PhoneScreenContent {
        let info = response.nextAction?.info
        let theme = info?.theme
        return PhoneScreenContent(
            headerPicURL: httpURL(response.nextAction?.title?.headerPic) ?? context.headerPicURL,
            serviceName: response.nextAction?.title?.name?.nonEmptyTrimmed ?? context.serviceName,
            headerHTML: HTMLDisclaimer.decodedNonEmpty(info?.disclaimers?.headerInfo),
            middleHTML: HTMLDisclaimer.decodedNonEmpty(info?.disclaimers?.middleInfo),
            footerHTML: HTMLDisclaimer.decodedNonEmpty(info?.disclaimers?.footerInfo),
            placeholder: label(theme?.textBox?.text) ?? L10n.text(.phonePlaceholder, language),
            buttonTitle: label(theme?.button?.text) ?? L10n.text(.continueButton, language),
            lockedDialCode: context.lockedDialCode,
            countryISO: context.countryISO,
            validationMessage: theme?.textBox?.errorMSG?.nonEmptyTrimmed,
            legalLinks: context.legalLinks
        )
    }

    /// `phn` is substituted for `{phone}` placeholders in the disclaimers.
    static func pin(from response: APIResponse, context: SessionContext, language: String, phn: String?) -> PinScreenContent {
        let info = response.nextAction?.info
        let theme = info?.theme
        let textBox = theme?.textBox
        func html(_ raw: String?) -> String? {
            HTMLDisclaimer.decodedNonEmpty(raw).map { substitutePhone($0, phn: phn) }
        }
        return PinScreenContent(
            headerPicURL: httpURL(response.nextAction?.title?.headerPic) ?? context.headerPicURL,
            serviceName: response.nextAction?.title?.name?.nonEmptyTrimmed ?? context.serviceName,
            otpTopHTML: html(info?.disclaimers?.otpTopHeaderInfo),
            headerHTML: html(info?.disclaimers?.headerInfo),
            middleHTML: html(info?.disclaimers?.middleInfo),
            footerHTML: html(info?.disclaimers?.footerInfo),
            pinLength: textBox?.effectivePinLength ?? 6,
            usesNumericKeyboard: textBox?.usesNumericKeyboard ?? true,
            buttonTitle: label(theme?.button?.text) ?? L10n.text(.confirmButton, language),
            wrongNumberTitle: label(theme?.wrongNumber?.text),
            validationMessage: textBox?.errorMSG?.nonEmptyTrimmed,
            legalLinks: legalLinks(theme).isEmpty ? context.legalLinks : legalLinks(theme),
            resendTitle: label(theme?.askCodeAgain?.text),
            resendCountdown: theme?.askCodeAgain?.countDown
        )
    }

    static func legalLinks(_ theme: ThemeInfo?) -> [LegalLink] {
        [("terms", theme?.termsAndConditions), ("privacy", theme?.privacyPolicies)].compactMap { id, legal in
            guard let title = label(legal?.text), let content = legal?.content?.nonEmptyTrimmed else { return nil }
            return LegalLink(id: id, title: title, html: HTMLDisclaimer.formURLDecode(content))
        }
    }

    /// Labels may contain HTML or be URL-encoded; reduce them to trimmed plain text.
    static func label(_ raw: String?) -> String? {
        guard let raw else { return nil }
        return HTMLDisclaimer.plainText(HTMLDisclaimer.formURLDecode(raw)).nonEmptyTrimmed
    }

    static func httpURL(_ raw: String?) -> URL? {
        guard let raw = raw?.nonEmptyTrimmed, raw.lowercased().hasPrefix("http") else { return nil }
        return URL(string: raw)
    }

    private static func substitutePhone(_ html: String, phn: String?) -> String {
        guard let phn, !phn.isEmpty else { return html }
        // Keep the number left-to-right inside RTL text.
        let isolated = "\u{202A}+\(phn)\u{202C}"
        return html.replacingOccurrences(of: "{phone}", with: isolated)
    }
}
