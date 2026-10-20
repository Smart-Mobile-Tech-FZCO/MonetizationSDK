import Foundation

enum APIAction: String, Sendable {
    case initiate = "1"
    case sendPin = "2"
    case verifyPin = "3"
}

/// Top-level body of every request.
struct RequestEnvelope: Encodable, Equatable, Sendable {
    let deviceInfo: DeviceInfo
    let request: ActionRequest
    let newSDK: Bool
    let referrer: ReferrerPayload

    init(deviceInfo: DeviceInfo, request: ActionRequest, referrer: ReferrerPayload) {
        self.deviceInfo = deviceInfo
        self.request = request
        self.newSDK = true
        self.referrer = referrer
    }

    enum CodingKeys: String, CodingKey {
        case deviceInfo = "DeviceInfo"
        case request = "Request"
        case newSDK = "NewSDK"
        case referrer = "Referrer"
    }
}

struct DeviceInfo: Encodable, Equatable, Sendable {
    let packageName: String
    let deviceID: String
    let langCode: String

    enum CodingKeys: String, CodingKey {
        case packageName = "PackageName"
        case deviceID = "DeviceID"
        case langCode = "LangCode"
    }
}

/// The `Request` object. Which keys appear depends on the action:
/// Initiate has no `SessionID`; sendPin adds `phn`; verifyPin adds `PinCode`.
struct ActionRequest: Encodable, Equatable, Sendable {
    let action: APIAction
    let transactionID: String
    let sessionID: String?
    let phn: String?
    let pinCode: String?

    static func initiate(transactionID: String) -> ActionRequest {
        ActionRequest(action: .initiate, transactionID: transactionID, sessionID: nil, phn: nil, pinCode: nil)
    }

    static func sendPin(sessionID: String, transactionID: String, phn: String) -> ActionRequest {
        ActionRequest(action: .sendPin, transactionID: transactionID, sessionID: sessionID, phn: phn, pinCode: nil)
    }

    static func verifyPin(sessionID: String, transactionID: String, pinCode: String) -> ActionRequest {
        ActionRequest(action: .verifyPin, transactionID: transactionID, sessionID: sessionID, phn: nil, pinCode: pinCode)
    }

    enum CodingKeys: String, CodingKey {
        case sessionID = "SessionID"
        case transactionID = "TransactionID"
        case action = "Action"
        case phn
        case pinCode = "PinCode"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(sessionID, forKey: .sessionID)
        try c.encode(transactionID, forKey: .transactionID)
        try c.encode(action.rawValue, forKey: .action)
        try c.encodeIfPresent(phn, forKey: .phn)
        try c.encodeIfPresent(pinCode, forKey: .pinCode)
    }
}

/// `Referrer.Native`. Kept in one type because the backend may still change these fields.
struct ReferrerPayload: Encodable, Equatable, Sendable {
    static let version = 2

    let naming: String
    let idOffer: Int
    let deeplink: String
    let country: String?

    init(_ referrer: PaymentReferrer) {
        naming = referrer.naming
        idOffer = referrer.idOffer
        deeplink = referrer.deeplink
        let trimmed = referrer.country?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        country = trimmed.isEmpty ? nil : trimmed
    }

    private enum OuterKeys: String, CodingKey { case native = "Native" }

    private enum NativeKeys: String, CodingKey {
        case naming = "Naming"
        case version = "Version"
        case idOffer = "IDOffer"
        case deeplink = "Deeplink"
        case country = "Country"
    }

    func encode(to encoder: Encoder) throws {
        var outer = encoder.container(keyedBy: OuterKeys.self)
        var native = outer.nestedContainer(keyedBy: NativeKeys.self, forKey: .native)
        try native.encode(naming, forKey: .naming)
        try native.encode(Self.version, forKey: .version)
        try native.encode(idOffer, forKey: .idOffer)
        try native.encode(deeplink, forKey: .deeplink)
        try native.encodeIfPresent(country, forKey: .country)
    }
}

/// Builds envelopes. Every call gets a fresh TransactionID; the backend rejects reused ones.
struct RequestFactory: Sendable {
    let deviceInfo: DeviceInfo
    let referrer: ReferrerPayload
    let makeTransactionID: @Sendable () -> String

    init(deviceInfo: DeviceInfo,
         referrer: ReferrerPayload,
         makeTransactionID: @escaping @Sendable () -> String = { UUID().uuidString }) {
        self.deviceInfo = deviceInfo
        self.referrer = referrer
        self.makeTransactionID = makeTransactionID
    }

    func initiate() -> RequestEnvelope {
        envelope(.initiate(transactionID: makeTransactionID()))
    }

    func sendPin(sessionID: String, phn: String) -> RequestEnvelope {
        envelope(.sendPin(sessionID: sessionID, transactionID: makeTransactionID(), phn: phn))
    }

    func verifyPin(sessionID: String, pinCode: String) -> RequestEnvelope {
        envelope(.verifyPin(sessionID: sessionID, transactionID: makeTransactionID(), pinCode: pinCode))
    }

    private func envelope(_ request: ActionRequest) -> RequestEnvelope {
        RequestEnvelope(deviceInfo: deviceInfo, request: request, referrer: referrer)
    }
}
