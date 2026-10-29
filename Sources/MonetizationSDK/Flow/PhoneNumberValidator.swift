import Foundation
import PhoneNumberKit

enum PhoneValidation: Equatable {
    /// `phn` as the backend wants it: dial code + national number, digits only, no `+`.
    case valid(phn: String)
    case invalid(L10n.Key)

    var phn: String? {
        if case let .valid(phn) = self { return phn }
        return nil
    }
}

@MainActor
protocol PhoneValidating {
    func validate(local: String, dialCode: String) -> PhoneValidation
    func maxNationalDigits(dialCode: String) -> Int?
}

/// Mobile-number validation backed by PhoneNumberKit.
@MainActor
final class PhoneNumberValidator: PhoneValidating {
    static let shared = PhoneNumberValidator()

    private let utility = PhoneNumberUtility()

    func validate(local: String, dialCode: String) -> PhoneValidation {
        let localDigits = local.westernDigits.filter(\.isNumber)
        guard !localDigits.isEmpty else { return .invalid(.enterPhone) }
        let dialDigits = dialCode.filter(\.isNumber)

        guard let region = region(forDialCode: dialCode) else {
            // Unknown dial code: accept anything plausible and let the backend decide.
            let national = Self.stripLeadingZeros(localDigits)
            return national.count >= 4 && !dialDigits.isEmpty
                ? .valid(phn: dialDigits + national)
                : .invalid(.invalidPhone)
        }

        guard let number = try? utility.parse(localDigits, withRegion: region, ignoreType: false) else {
            return .invalid(.invalidPhone)
        }
        switch number.type {
        case .mobile, .fixedOrMobile:
            let e164 = utility.format(number, toType: .e164)
            return .valid(phn: e164.filter(\.isNumber))
        default:
            return .invalid(.invalidMobile)
        }
    }

    func maxNationalDigits(dialCode: String) -> Int? {
        guard let region = region(forDialCode: dialCode) else { return nil }
        let mobile = utility.possiblePhoneNumberLengths(forCountry: region, phoneNumberType: .mobile, lengthType: .national)
        let either = utility.possiblePhoneNumberLengths(forCountry: region, phoneNumberType: .fixedOrMobile, lengthType: .national)
        return (mobile + either).max()
    }

    private func region(forDialCode dialCode: String) -> String? {
        let digits = dialCode.filter(\.isNumber)
        guard !digits.isEmpty, let code = UInt64(digits) else { return nil }
        return utility.mainCountry(forCode: code)
    }

    static func stripLeadingZeros(_ digits: String) -> String {
        String(digits.drop(while: { $0 == "0" }))
    }
}

extension String {
    /// Maps Arabic-Indic (٠-٩) and Persian (۰-۹) digits to 0-9.
    var westernDigits: String {
        String(unicodeScalars.map { scalar -> Character in
            switch scalar.value {
            case 0x0660...0x0669: return Character(UnicodeScalar(scalar.value - 0x0660 + 0x30)!)
            case 0x06F0...0x06F9: return Character(UnicodeScalar(scalar.value - 0x06F0 + 0x30)!)
            default: return Character(scalar)
            }
        })
    }
}
