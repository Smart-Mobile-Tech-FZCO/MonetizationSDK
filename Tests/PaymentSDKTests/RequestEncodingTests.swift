import XCTest
@testable import PaymentSDK

final class RequestEncodingTests: XCTestCase {

    /// Keys the merged Postman v2 + prototype referrer adds to the fixtures' `Naming`/`Version`.
    private let mergedNativeKeys: Set<String> = ["Naming", "Version", "IDOffer", "Deeplink"]

    private func encode(_ envelope: RequestEnvelope) throws -> [String: Any] {
        let data = try JSONEncoder().encode(envelope)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func keys(_ object: Any?) -> Set<String> {
        Set((object as? [String: Any])?.keys.map { $0 } ?? [])
    }

    private func assertMatchesFixture(_ envelope: RequestEnvelope, fixture: String,
                                      file: StaticString = #filePath, line: UInt = #line) throws {
        let encoded = try encode(envelope)
        let expected = try Fixture.jsonObject(fixture)

        XCTAssertEqual(keys(encoded), keys(expected), "top-level keys", file: file, line: line)
        XCTAssertEqual(keys(encoded["DeviceInfo"]), keys(expected["DeviceInfo"]), "DeviceInfo keys", file: file, line: line)
        XCTAssertEqual(keys(encoded["Request"]), keys(expected["Request"]), "Request keys", file: file, line: line)
        XCTAssertEqual(keys(encoded["Referrer"]), ["Native"], file: file, line: line)

        let native = (encoded["Referrer"] as? [String: Any])?["Native"]
        let fixtureNative = keys((expected["Referrer"] as? [String: Any])?["Native"])
        XCTAssertTrue(fixtureNative.isSubset(of: keys(native)), "fixture Native keys present", file: file, line: line)
        XCTAssertEqual(keys(native), mergedNativeKeys, "merged Native keys (Country omitted)", file: file, line: line)

        XCTAssertEqual(encoded["NewSDK"] as? Bool, true, file: file, line: line)
        let request = try XCTUnwrap(encoded["Request"] as? [String: Any], file: file, line: line)
        XCTAssertTrue(request["Action"] is String, "Action must be a string", file: file, line: line)
        XCTAssertEqual(request["Action"] as? String,
                       (expected["Request"] as? [String: Any])?["Action"] as? String, file: file, line: line)
    }

    func testInitiateMatchesFixtureAndHasNoSessionID() throws {
        let envelope = makeFactory().initiate()
        try assertMatchesFixture(envelope, fixture: "initiate.request")
        let request = try XCTUnwrap(try encode(envelope)["Request"] as? [String: Any])
        XCTAssertNil(request["SessionID"])
        XCTAssertEqual(Set(request.keys), ["TransactionID", "Action"])
    }

    func testSendPinMatchesFixtureAndUsesPhn() throws {
        let envelope = makeFactory().sendPin(sessionID: "S1", phn: "96171020136")
        try assertMatchesFixture(envelope, fixture: "sendpin.request")
        let request = try XCTUnwrap(try encode(envelope)["Request"] as? [String: Any])
        XCTAssertEqual(request["phn"] as? String, "96171020136")
        XCTAssertEqual(request["SessionID"] as? String, "S1")
        XCTAssertNil(request["MSISDN"])
        XCTAssertNil(request["PinCode"])
    }

    func testVerifyPinMatchesFixture() throws {
        let envelope = makeFactory().verifyPin(sessionID: "S1", pinCode: "12345")
        try assertMatchesFixture(envelope, fixture: "verifypin.request")
        let request = try XCTUnwrap(try encode(envelope)["Request"] as? [String: Any])
        XCTAssertEqual(request["PinCode"] as? String, "12345")
        XCTAssertNil(request["phn"])
    }

    func testReferrerDefaultsAndValues() throws {
        let native = try nativeObject(PaymentReferrer())
        XCTAssertEqual(native["Naming"] as? String, "")
        XCTAssertEqual(native["Version"] as? Int, 2)
        XCTAssertEqual(native["IDOffer"] as? Int, -1)
        XCTAssertEqual(native["Deeplink"] as? String, "")
        XCTAssertNil(native["Country"])

        let custom = try nativeObject(PaymentReferrer(naming: "campaign", idOffer: 42, deeplink: "app://x", country: "LB"))
        XCTAssertEqual(native.count + 1, custom.count)
        XCTAssertEqual(custom["Naming"] as? String, "campaign")
        XCTAssertEqual(custom["IDOffer"] as? Int, 42)
        XCTAssertEqual(custom["Deeplink"] as? String, "app://x")
        XCTAssertEqual(custom["Country"] as? String, "LB")
    }

    func testEmptyCountryIsOmitted() throws {
        XCTAssertNil(try nativeObject(PaymentReferrer(country: "  "))["Country"])
        XCTAssertNil(try nativeObject(PaymentReferrer(country: ""))["Country"])
    }

    func testRequestsRouteToTheirEndpoints() async throws {
        let stub = StubAPIClient([.fixture("initiate.response.success"), .fixture("sendpin.response.success")])
        let api = PaymentAPI(client: stub, initiateURL: testInitiateURL, apiURL: testAPIURL)
        _ = try await api.send(makeFactory().initiate())
        _ = try await api.send(makeFactory().sendPin(sessionID: "S", phn: "1"))
        XCTAssertEqual(stub.sent.map(\.url), [testInitiateURL, testAPIURL])
    }

    func testDefaultEndpoints() {
        let config = PaymentSDKConfiguration()
        XCTAssertEqual(config.initiateURL.absoluteString, "https://asarpluss.online")
        XCTAssertEqual(config.apiURL.absoluteString, "https://d31e0jpxlj21ku.cloudfront.net")
        XCTAssertFalse(config.isOnLaunch)
        XCTAssertFalse(config.isLoggingEnabled)
    }


    func testLoggerMasksPhoneNumbers() {
        XCTAssertEqual(SDKLogger.mask("96171020136"), "9617•••••36")
        XCTAssertEqual(SDKLogger.mask(nil), "-")
    }

    private func nativeObject(_ referrer: PaymentReferrer) throws -> [String: Any] {
        let encoded = try encode(makeFactory(referrer: referrer).initiate())
        return try XCTUnwrap((encoded["Referrer"] as? [String: Any])?["Native"] as? [String: Any])
    }
}
