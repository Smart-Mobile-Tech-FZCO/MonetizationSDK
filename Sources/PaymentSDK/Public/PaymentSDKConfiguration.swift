import Foundation

/// Everything the host app can configure. Pass it to `PaymentSDK.configure(_:onResult:)`.
public struct PaymentSDKConfiguration {
    /// `true`: the SDK presents itself once, right after launch.
    /// `false`: nothing happens until `PaymentSDK.present(from:)` or the SwiftUI modifier is used.
    public var isOnLaunch: Bool
    /// Endpoint for Initiate (Action "1").
    public var initiateURL: URL
    /// Endpoint for sendPin (Action "2") and verifyPin (Action "3").
    public var apiURL: URL
    /// Sent as `DeviceInfo.PackageName`. `nil` uses the host app's bundle identifier.
    public var packageName: String?
    /// Values sent in `Referrer.Native`.
    public var referrer: PaymentReferrer
    /// Prints request/response summaries to the console. PIN codes and full phone numbers are never logged.
    public var isLoggingEnabled: Bool

    public static let defaultInitiateURL = URL(string: "https://asarpluss.online")!
    public static let defaultAPIURL = URL(string: "https://d31e0jpxlj21ku.cloudfront.net")!

    public init(isOnLaunch: Bool = false,
                initiateURL: URL = PaymentSDKConfiguration.defaultInitiateURL,
                apiURL: URL = PaymentSDKConfiguration.defaultAPIURL,
                packageName: String? = nil,
                referrer: PaymentReferrer = PaymentReferrer(),
                isLoggingEnabled: Bool = false) {
        self.isOnLaunch = isOnLaunch
        self.initiateURL = initiateURL
        self.apiURL = apiURL
        self.packageName = packageName
        self.referrer = referrer
        self.isLoggingEnabled = isLoggingEnabled
    }
}

/// Attribution values sent with every request in `Referrer.Native`.
public struct PaymentReferrer: Equatable {
    public var naming: String
    public var idOffer: Int
    public var deeplink: String
    /// ISO country code, e.g. `"LB"`. Omitted from the request when `nil` or empty.
    public var country: String?

    public init(naming: String = "", idOffer: Int = -1, deeplink: String = "", country: String? = nil) {
        self.naming = naming
        self.idOffer = idOffer
        self.deeplink = deeplink
        self.country = country
    }
}

