import XCTest
@testable import MonetizationSDK

@MainActor
final class SessionAndTransactionTests: XCTestCase {

    private let initiateSession = "2deaa71c-b7c2-4120-a11e-3cc1f025227f"

    func testSessionIDIsReusedForEveryCallInTheSession() async {
        let stub = StubAPIClient([
            .fixture("initiate.response.success"),
            .json(#"{"Error":0,"SessionID":"2deaa71c-b7c2-4120-a11e-3cc1f025227f","NextAction":{"Action":3}}"#),
            .fixture("verifypin.response.wrong-pin"),
        ])
        let flow = makeCoordinator(stub)
        await flow.start()
        flow.phoneNumber = "71020136"
        await flow.submitPhone()
        flow.pin = "123456"
        await flow.submitPin()

        XCTAssertNil(stub.requests[0].sessionID)
        XCTAssertEqual(stub.requests[1].sessionID, initiateSession)
        XCTAssertEqual(stub.requests[2].sessionID, initiateSession)
    }

    func testEmptySessionIDNeverOverwritesTheStoredOne() async {
        let stub = StubAPIClient([
            .fixture("initiate.response.success"),
            .json(#"{"Error":1,"MessageToShow":"Try later","SessionID":"","NextAction":{}}"#),
            .json(#"{"Error":1,"MessageToShow":"Try later","SessionID":"   ","NextAction":{}}"#),
            .fixture("sendpin.response.success"),
        ])
        let flow = makeCoordinator(stub)
        await flow.start()
        flow.phoneNumber = "71020136"
        await flow.submitPhone()
        await flow.submitPhone()
        XCTAssertEqual(flow.sessionID, initiateSession, "\"\" and blank SessionIDs were ignored")
        XCTAssertEqual(flow.screen, .phone)

        await flow.submitPhone()
        XCTAssertEqual(stub.requests.dropFirst().map(\.sessionID), [initiateSession, initiateSession, initiateSession])
        XCTAssertEqual(flow.screen, .pin)
    }

    func testNewSessionIDFromBackendReplacesTheOldOne() async {
        let stub = StubAPIClient([
            .fixture("initiate.response.success"),
            .json(#"{"Error":0,"SessionID":"NEW","NextAction":{"Action":3}}"#),
            .fixture("verifypin.response.wrong-pin"),
        ])
        let flow = makeCoordinator(stub)
        await flow.start()
        flow.phoneNumber = "71020136"
        await flow.submitPhone()
        flow.pin = "123456"
        await flow.submitPin()
        XCTAssertEqual(stub.requests.last?.sessionID, "NEW")
    }

    func testTransactionIDIsUniqueOnEveryCallIncludingRetries() async {
        let stub = StubAPIClient([
            .fixture("initiate.response.invalid-transaction"),
            .fixture("initiate.response.success"),
            .fixture("sendpin.response.invalid-transaction"),
            .failure(.network(.timedOut)),
            .fixture("sendpin.response.success"),
            .fixture("verifypin.response.wrong-pin"),
            .fixture("verifypin.response.wrong-pin"),
        ])
        let flow = makeCoordinator(stub)
        await flow.start()
        await flow.retry()
        flow.phoneNumber = "71020136"
        await flow.submitPhone()
        await flow.submitPhone()
        await flow.submitPhone()
        flow.pin = "12345"
        await flow.submitPin()
        flow.pin = "12345"
        await flow.submitPin()

        let ids = stub.requests.map(\.transactionID)
        XCTAssertEqual(ids.count, 7)
        XCTAssertEqual(Set(ids).count, ids.count, "every request has its own TransactionID")
        XCTAssertTrue(ids.allSatisfy { UUID(uuidString: $0) != nil })
    }

    func testEveryCallCarriesTheSameDeviceInfo() async {
        let stub = StubAPIClient([.fixture("initiate.response.success"), .fixture("sendpin.response.success")])
        let flow = makeCoordinator(stub)
        await flow.start()
        flow.phoneNumber = "71020136"
        await flow.submitPhone()
        let infos = stub.sent.map(\.envelope.deviceInfo)
        XCTAssertEqual(infos.count, 2)
        XCTAssertEqual(Set(infos.map(\.deviceID)).count, 1)
        XCTAssertFalse(infos[0].deviceID.isEmpty)
    }

    func testFactoryGeneratesFreshTransactionIDs() {
        let factory = makeFactory()
        let ids = (0..<50).map { _ in factory.sendPin(sessionID: "S", phn: "1").request.transactionID }
        XCTAssertEqual(Set(ids).count, 50)
    }
}
