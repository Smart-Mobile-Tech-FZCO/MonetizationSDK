import Foundation
import XCTest
@testable import MonetizationSDK

enum Fixture {
    static func data(_ name: String, file: StaticString = #filePath, line: UInt = #line) -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Missing fixture \(name).json", file: file, line: line)
            return Data()
        }
        return data
    }

    static func response(_ name: String) throws -> APIResponse {
        try JSONDecoder().decode(APIResponse.self, from: data(name))
    }

    static func jsonObject(_ name: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data(name)) as? [String: Any])
    }

    static let allResponses = [
        "initiate.response.success",
        "initiate.response.invalid-transaction",
        "sendpin.response.success",
        "sendpin.response.invalid-transaction",
        "verifypin.response.wrong-pin",
        "verifypin.response.invalid-session",
        "verifypin.response.invalid-transaction",
    ]
}

/// Returns queued responses in order and records every request.
final class StubAPIClient: PaymentAPIClient, @unchecked Sendable {
    enum Reply {
        case fixture(String)
        case json(String)
        case failure(APIClientError)
    }

    private let lock = NSLock()
    private var replies: [Reply]
    private var _sent: [(envelope: RequestEnvelope, url: URL)] = []

    init(_ replies: [Reply] = []) {
        self.replies = replies
    }

    var sent: [(envelope: RequestEnvelope, url: URL)] {
        lock.lock(); defer { lock.unlock() }
        return _sent
    }

    var requests: [ActionRequest] { sent.map(\.envelope.request) }

    func enqueue(_ reply: Reply) {
        lock.lock(); defer { lock.unlock() }
        replies.append(reply)
    }

    func send(_ envelope: RequestEnvelope, to url: URL) async throws -> APIResponse {
        let reply: Reply? = {
            lock.lock(); defer { lock.unlock() }
            _sent.append((envelope, url))
            return replies.isEmpty ? nil : replies.removeFirst()
        }()
        switch reply {
        case .fixture(let name):
            return try JSONDecoder().decode(APIResponse.self, from: Fixture.data(name))
        case .json(let json):
            do {
                return try JSONDecoder().decode(APIResponse.self, from: Data(json.utf8))
            } catch {
                throw APIClientError.decoding
            }
        case .failure(let error):
            throw error
        case nil:
            throw APIClientError.network(.notConnectedToInternet)
        }
    }
}

final class InMemoryDeviceIDStore: DeviceIDStore {
    var value: String?
    var failsWrites: Bool
    private(set) var writeCount = 0

    init(value: String? = nil, failsWrites: Bool = false) {
        self.value = value
        self.failsWrites = failsWrites
    }

    func read() -> String? { value }

    func write(_ value: String) -> Bool {
        writeCount += 1
        guard !failsWrites else { return false }
        self.value = value
        return true
    }
}

let testInitiateURL = URL(string: "https://initiate.test")!
let testAPIURL = URL(string: "https://api.test")!

func makeFactory(referrer: MonetizationReferrer = MonetizationReferrer()) -> RequestFactory {
    RequestFactory(
        deviceInfo: DeviceInfo(packageName: "com.example.host", deviceID: "004FD5D9-7B47-4D73-A66A-17973C2EFCE5", langCode: "en"),
        referrer: ReferrerPayload(referrer)
    )
}

@MainActor
func makeCoordinator(_ stub: StubAPIClient,
                     themes: ThemeProviding = BundledThemeProvider(),
                     language: String = "en") -> FlowCoordinator {
    FlowCoordinator(
        api: PaymentAPI(client: stub, initiateURL: testInitiateURL, apiURL: testAPIURL),
        factory: makeFactory(),
        themes: themes,
        validator: PhoneNumberValidator.shared,
        language: language,
        initialDocument: BundledThemeProvider().resolve(themeID: nil),
        defaultDialCode: "961",
        errorDismissDelay: nil
    )
}

/// Serves an in-memory theme file under a given name, else the real bundle.
struct OverridingThemeProvider: ThemeProviding {
    let overrides: [String: String]

    func document(forThemeID themeID: String?) async -> PresentationDocument {
        let overrides = self.overrides
        return BundledThemeProvider(loadData: { name in
            if let json = overrides[name] { return Data(json.utf8) }
            return BundledThemeProvider.loadFromModuleBundle(name)
        }).resolve(themeID: themeID)
    }
}
