import Foundation

/// Builds the `DeviceInfo` sent with every request.
struct DeviceInfoProvider {
    let identity: DeviceIdentity
    let packageNameOverride: String?
    let preferredLanguages: () -> [String]
    let bundleIdentifier: () -> String?

    init(identity: DeviceIdentity,
         packageNameOverride: String?,
         preferredLanguages: @escaping () -> [String] = { Locale.preferredLanguages },
         bundleIdentifier: @escaping () -> String? = { Bundle.main.bundleIdentifier }) {
        self.identity = identity
        self.packageNameOverride = packageNameOverride
        self.preferredLanguages = preferredLanguages
        self.bundleIdentifier = bundleIdentifier
    }

    var languageCode: String {
        Self.languageCode(from: preferredLanguages())
    }

    var packageName: String {
        packageNameOverride?.nonEmptyTrimmed ?? bundleIdentifier() ?? ""
    }

    func deviceInfo() -> DeviceInfo {
        DeviceInfo(packageName: packageName, deviceID: identity.deviceID, langCode: languageCode)
    }

    /// The device language as 2 lowercase letters: `"ar-LB"` → `"ar"`, `"zh-Hans-CN"` → `"zh"`.
    /// Anything that is not a 2-letter code falls back to `"en"`.
    static func languageCode(from preferred: [String]) -> String {
        guard let first = preferred.first else { return "en" }
        let language = first
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first
            .map { $0.lowercased() } ?? ""
        let isTwoLetters = language.count == 2 && language.allSatisfy { $0.isASCII && $0.isLetter }
        return isTwoLetters ? language : "en"
    }

    static func isRightToLeft(_ languageCode: String) -> Bool {
        Locale.characterDirection(forLanguage: languageCode) == .rightToLeft
    }
}
