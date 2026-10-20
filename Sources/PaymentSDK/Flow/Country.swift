import Foundation

struct Country: Identifiable, Equatable, Hashable, Sendable {
    let code: String
    let name: String
    let dial: String

    var id: String { code }

    var flag: String {
        code.unicodeScalars.reduce(into: "") { result, scalar in
            if let flagScalar = UnicodeScalar(127397 + scalar.value) {
                result.unicodeScalars.append(flagScalar)
            }
        }
    }

    var shortLabel: String { "\(flag) \(dial)" }
    var rowLabel: String { "\(flag)  \(name) (\(dial))" }
}

enum CountryCatalog {

    static let all: [Country] = [
        Country(code: "AF", name: "Afghanistan", dial: "+93"),
        Country(code: "AL", name: "Albania", dial: "+355"),
        Country(code: "DZ", name: "Algeria", dial: "+213"),
        Country(code: "AD", name: "Andorra", dial: "+376"),
        Country(code: "AO", name: "Angola", dial: "+244"),
        Country(code: "AR", name: "Argentina", dial: "+54"),
        Country(code: "AM", name: "Armenia", dial: "+374"),
        Country(code: "AU", name: "Australia", dial: "+61"),
        Country(code: "AT", name: "Austria", dial: "+43"),
        Country(code: "AZ", name: "Azerbaijan", dial: "+994"),
        Country(code: "BH", name: "Bahrain", dial: "+973"),
        Country(code: "BD", name: "Bangladesh", dial: "+880"),
        Country(code: "BY", name: "Belarus", dial: "+375"),
        Country(code: "BE", name: "Belgium", dial: "+32"),
        Country(code: "BJ", name: "Benin", dial: "+229"),
        Country(code: "BO", name: "Bolivia", dial: "+591"),
        Country(code: "BA", name: "Bosnia and Herzegovina", dial: "+387"),
        Country(code: "BW", name: "Botswana", dial: "+267"),
        Country(code: "BR", name: "Brazil", dial: "+55"),
        Country(code: "BN", name: "Brunei", dial: "+673"),
        Country(code: "BG", name: "Bulgaria", dial: "+359"),
        Country(code: "BF", name: "Burkina Faso", dial: "+226"),
        Country(code: "BI", name: "Burundi", dial: "+257"),
        Country(code: "KH", name: "Cambodia", dial: "+855"),
        Country(code: "CM", name: "Cameroon", dial: "+237"),
        Country(code: "CA", name: "Canada", dial: "+1"),
        Country(code: "CL", name: "Chile", dial: "+56"),
        Country(code: "CN", name: "China", dial: "+86"),
        Country(code: "CO", name: "Colombia", dial: "+57"),
        Country(code: "CG", name: "Congo", dial: "+242"),
        Country(code: "CD", name: "Congo (DRC)", dial: "+243"),
        Country(code: "CR", name: "Costa Rica", dial: "+506"),
        Country(code: "CI", name: "Côte d'Ivoire", dial: "+225"),
        Country(code: "HR", name: "Croatia", dial: "+385"),
        Country(code: "CY", name: "Cyprus", dial: "+357"),
        Country(code: "CZ", name: "Czechia", dial: "+420"),
        Country(code: "DK", name: "Denmark", dial: "+45"),
        Country(code: "DO", name: "Dominican Republic", dial: "+1809"),
        Country(code: "EC", name: "Ecuador", dial: "+593"),
        Country(code: "EG", name: "Egypt", dial: "+20"),
        Country(code: "SV", name: "El Salvador", dial: "+503"),
        Country(code: "EE", name: "Estonia", dial: "+372"),
        Country(code: "ET", name: "Ethiopia", dial: "+251"),
        Country(code: "FI", name: "Finland", dial: "+358"),
        Country(code: "FR", name: "France", dial: "+33"),
        Country(code: "GE", name: "Georgia", dial: "+995"),
        Country(code: "DE", name: "Germany", dial: "+49"),
        Country(code: "GH", name: "Ghana", dial: "+233"),
        Country(code: "GR", name: "Greece", dial: "+30"),
        Country(code: "GT", name: "Guatemala", dial: "+502"),
        Country(code: "HN", name: "Honduras", dial: "+504"),
        Country(code: "HK", name: "Hong Kong", dial: "+852"),
        Country(code: "HU", name: "Hungary", dial: "+36"),
        Country(code: "IS", name: "Iceland", dial: "+354"),
        Country(code: "IN", name: "India", dial: "+91"),
        Country(code: "ID", name: "Indonesia", dial: "+62"),
        Country(code: "IR", name: "Iran", dial: "+98"),
        Country(code: "IQ", name: "Iraq", dial: "+964"),
        Country(code: "IE", name: "Ireland", dial: "+353"),
        Country(code: "IL", name: "Israel", dial: "+972"),
        Country(code: "IT", name: "Italy", dial: "+39"),
        Country(code: "JM", name: "Jamaica", dial: "+1876"),
        Country(code: "JP", name: "Japan", dial: "+81"),
        Country(code: "JO", name: "Jordan", dial: "+962"),
        Country(code: "KZ", name: "Kazakhstan", dial: "+7"),
        Country(code: "KE", name: "Kenya", dial: "+254"),
        Country(code: "KW", name: "Kuwait", dial: "+965"),
        Country(code: "KG", name: "Kyrgyzstan", dial: "+996"),
        Country(code: "LA", name: "Laos", dial: "+856"),
        Country(code: "LV", name: "Latvia", dial: "+371"),
        Country(code: "LB", name: "Lebanon", dial: "+961"),
        Country(code: "LY", name: "Libya", dial: "+218"),
        Country(code: "LT", name: "Lithuania", dial: "+370"),
        Country(code: "LU", name: "Luxembourg", dial: "+352"),
        Country(code: "MO", name: "Macau", dial: "+853"),
        Country(code: "MG", name: "Madagascar", dial: "+261"),
        Country(code: "MW", name: "Malawi", dial: "+265"),
        Country(code: "MY", name: "Malaysia", dial: "+60"),
        Country(code: "MV", name: "Maldives", dial: "+960"),
        Country(code: "ML", name: "Mali", dial: "+223"),
        Country(code: "MT", name: "Malta", dial: "+356"),
        Country(code: "MR", name: "Mauritania", dial: "+222"),
        Country(code: "MU", name: "Mauritius", dial: "+230"),
        Country(code: "MX", name: "Mexico", dial: "+52"),
        Country(code: "MD", name: "Moldova", dial: "+373"),
        Country(code: "MC", name: "Monaco", dial: "+377"),
        Country(code: "MN", name: "Mongolia", dial: "+976"),
        Country(code: "ME", name: "Montenegro", dial: "+382"),
        Country(code: "MA", name: "Morocco", dial: "+212"),
        Country(code: "MZ", name: "Mozambique", dial: "+258"),
        Country(code: "MM", name: "Myanmar", dial: "+95"),
        Country(code: "NA", name: "Namibia", dial: "+264"),
        Country(code: "NP", name: "Nepal", dial: "+977"),
        Country(code: "NL", name: "Netherlands", dial: "+31"),
        Country(code: "NZ", name: "New Zealand", dial: "+64"),
        Country(code: "NI", name: "Nicaragua", dial: "+505"),
        Country(code: "NE", name: "Niger", dial: "+227"),
        Country(code: "NG", name: "Nigeria", dial: "+234"),
        Country(code: "MK", name: "North Macedonia", dial: "+389"),
        Country(code: "NO", name: "Norway", dial: "+47"),
        Country(code: "OM", name: "Oman", dial: "+968"),
        Country(code: "PK", name: "Pakistan", dial: "+92"),
        Country(code: "PS", name: "Palestine", dial: "+970"),
        Country(code: "PA", name: "Panama", dial: "+507"),
        Country(code: "PG", name: "Papua New Guinea", dial: "+675"),
        Country(code: "PY", name: "Paraguay", dial: "+595"),
        Country(code: "PE", name: "Peru", dial: "+51"),
        Country(code: "PH", name: "Philippines", dial: "+63"),
        Country(code: "PL", name: "Poland", dial: "+48"),
        Country(code: "PT", name: "Portugal", dial: "+351"),
        Country(code: "PR", name: "Puerto Rico", dial: "+1787"),
        Country(code: "QA", name: "Qatar", dial: "+974"),
        Country(code: "RO", name: "Romania", dial: "+40"),
        Country(code: "RU", name: "Russia", dial: "+7"),
        Country(code: "RW", name: "Rwanda", dial: "+250"),
        Country(code: "SA", name: "Saudi Arabia", dial: "+966"),
        Country(code: "SN", name: "Senegal", dial: "+221"),
        Country(code: "RS", name: "Serbia", dial: "+381"),
        Country(code: "SG", name: "Singapore", dial: "+65"),
        Country(code: "SK", name: "Slovakia", dial: "+421"),
        Country(code: "SI", name: "Slovenia", dial: "+386"),
        Country(code: "SO", name: "Somalia", dial: "+252"),
        Country(code: "ZA", name: "South Africa", dial: "+27"),
        Country(code: "KR", name: "South Korea", dial: "+82"),
        Country(code: "ES", name: "Spain", dial: "+34"),
        Country(code: "LK", name: "Sri Lanka", dial: "+94"),
        Country(code: "SD", name: "Sudan", dial: "+249"),
        Country(code: "SE", name: "Sweden", dial: "+46"),
        Country(code: "CH", name: "Switzerland", dial: "+41"),
        Country(code: "SY", name: "Syria", dial: "+963"),
        Country(code: "TW", name: "Taiwan", dial: "+886"),
        Country(code: "TJ", name: "Tajikistan", dial: "+992"),
        Country(code: "TZ", name: "Tanzania", dial: "+255"),
        Country(code: "TH", name: "Thailand", dial: "+66"),
        Country(code: "TG", name: "Togo", dial: "+228"),
        Country(code: "TT", name: "Trinidad and Tobago", dial: "+1868"),
        Country(code: "TN", name: "Tunisia", dial: "+216"),
        Country(code: "TR", name: "Turkey", dial: "+90"),
        Country(code: "TM", name: "Turkmenistan", dial: "+993"),
        Country(code: "UG", name: "Uganda", dial: "+256"),
        Country(code: "UA", name: "Ukraine", dial: "+380"),
        Country(code: "AE", name: "United Arab Emirates", dial: "+971"),
        Country(code: "GB", name: "United Kingdom", dial: "+44"),
        Country(code: "US", name: "United States", dial: "+1"),
        Country(code: "UY", name: "Uruguay", dial: "+598"),
        Country(code: "UZ", name: "Uzbekistan", dial: "+998"),
        Country(code: "VE", name: "Venezuela", dial: "+58"),
        Country(code: "VN", name: "Vietnam", dial: "+84"),
        Country(code: "YE", name: "Yemen", dial: "+967"),
        Country(code: "ZM", name: "Zambia", dial: "+260"),
        Country(code: "ZW", name: "Zimbabwe", dial: "+263")
    ]

    /// `"961"` or `"+961"` → Lebanon. Unknown codes fall back to the first entry.
    static func country(forDial dial: String) -> Country {
        let normalized = "+" + dial.filter(\.isNumber)
        return all.first { $0.dial == normalized } ?? all[0]
    }

    static func country(forISO iso: String?) -> Country? {
        guard let iso = iso?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), !iso.isEmpty else { return nil }
        return all.first { $0.code == iso }
    }

    static func matchingDialCode(forNumber raw: String) -> String? {
        let digits = raw.filter { $0.isNumber }
        guard !digits.isEmpty else { return nil }

        let codes = all
            .map { $0.dial }
            .sorted { $0.count > $1.count }

        for dial in codes {
            let dialDigits = dial.filter { $0.isNumber }

            if digits.hasPrefix(dialDigits), digits.count > dialDigits.count {
                return dial
            }
        }
        return nil
    }
}
