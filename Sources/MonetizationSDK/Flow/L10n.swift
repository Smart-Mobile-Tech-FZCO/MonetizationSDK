import Foundation

/// SDK-owned copy, keyed by the device language (not the host app's localizations).
enum L10n {
    enum Key: String {
        case next, tryAgain, close, genericError, networkError
        case enterPhone, invalidPhone, invalidMobile, enterPin
        case phonePlaceholder, continueButton, confirmButton, wrongNumber, loading
    }

    private static let english: [Key: String] = [
        .next: "Next",
        .tryAgain: "Try again",
        .close: "Close",
        .genericError: "Something went wrong. Please try again.",
        .networkError: "We couldn't reach the server. Check your connection and try again.",
        .enterPhone: "Please enter your phone number.",
        .invalidPhone: "Please enter a valid phone number.",
        .invalidMobile: "Please enter a valid mobile number.",
        .enterPin: "Please enter the code you received.",
        .phonePlaceholder: "Phone number",
        .continueButton: "Continue",
        .confirmButton: "Confirm",
        .wrongNumber: "Wrong number?",
        .loading: "Loading…",
    ]

    private static let arabic: [Key: String] = [
        .next: "التالي",
        .tryAgain: "حاول مرة أخرى",
        .close: "إغلاق",
        .genericError: "حدث خطأ ما. يرجى المحاولة مرة أخرى.",
        .networkError: "تعذّر الاتصال بالخادم. تحقق من اتصالك وحاول مرة أخرى.",
        .enterPhone: "يرجى إدخال رقم هاتفك.",
        .invalidPhone: "يرجى إدخال رقم هاتف صالح.",
        .invalidMobile: "يرجى إدخال رقم جوال صالح.",
        .enterPin: "يرجى إدخال الرمز الذي وصلك.",
        .phonePlaceholder: "رقم الهاتف",
        .continueButton: "متابعة",
        .confirmButton: "تأكيد",
        .wrongNumber: "رقم خاطئ؟",
        .loading: "جارٍ التحميل…",
    ]

    static func text(_ key: Key, _ language: String) -> String {
        let table = language.lowercased().hasPrefix("ar") ? arabic : english
        return table[key] ?? english[key] ?? key.rawValue
    }
}
