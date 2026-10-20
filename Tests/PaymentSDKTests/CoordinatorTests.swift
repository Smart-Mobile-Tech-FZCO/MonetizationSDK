import XCTest
@testable import PaymentSDK

@MainActor
final class CoordinatorTests: XCTestCase {

    private var results: [PaymentResult] = []

    private func coordinator(_ stub: StubAPIClient, themes: ThemeProviding = BundledThemeProvider()) -> FlowCoordinator {
        results = []
        let flow = makeCoordinator(stub, themes: themes)
        flow.onFinish = { [weak self] in self?.results.append($0) }
        return flow
    }

    /// Initiate succeeded and the phone screen is up with a valid Lebanese number typed in.
    private func onPhoneScreen(_ stub: StubAPIClient) async -> FlowCoordinator {
        stub.enqueue(.fixture("initiate.response.success"))
        let flow = coordinator(stub)
        await flow.start()
        flow.phoneNumber = "71020136"
        return flow
    }

    private func onPinScreen(_ stub: StubAPIClient) async -> FlowCoordinator {
        let flow = await onPhoneScreen(stub)
        stub.enqueue(.fixture("sendpin.response.success"))
        await flow.submitPhone()
        XCTAssertEqual(flow.screen, .pin)
        return flow
    }

    // MARK: Initiate

    func testInitiateSuccessShowsPhoneScreenWithBackendContent() async throws {
        let flow = await onPhoneScreen(StubAPIClient())
        XCTAssertEqual(flow.screen, .phone, "299 is not bundled → default-theme (single) → phone directly")
        XCTAssertEqual(flow.document.sourceName, "default-theme")
        XCTAssertEqual(flow.sessionID, "2deaa71c-b7c2-4120-a11e-3cc1f025227f")

        let content = try XCTUnwrap(flow.phoneContent)
        XCTAssertEqual(content.lockedDialCode, "961")
        XCTAssertEqual(flow.dialCodeForPhone, "961")
        XCTAssertEqual(content.countryISO, "LB")
        XCTAssertEqual(content.placeholder, "Phone number")
        XCTAssertEqual(content.buttonTitle, "Subscribe")
        XCTAssertEqual(content.headerPicURL?.host, "asarpluss.online")
        XCTAssertEqual(content.headerHTML.map(HTMLDisclaimer.plainText), "Enter your phone number")
        XCTAssertNil(content.middleHTML)
        XCTAssertEqual(content.legalLinks.map(\.title), ["Terms & Conditions", "Privacy Policy"])
    }

    func testInitiateErrorShowsRetryScreen() async {
        let stub = StubAPIClient([.fixture("initiate.response.invalid-transaction")])
        let flow = coordinator(stub)
        await flow.start()
        XCTAssertEqual(flow.screen, .retry)
        XCTAssertEqual(flow.retryMessage, "Invalid TransactionID")
        XCTAssertNil(flow.sessionID)
        XCTAssertTrue(results.isEmpty)
    }

    func testInitiateNetworkAndDecodingFailuresShowRetryScreen() async {
        for failure in [APIClientError.network(.timedOut), .httpStatus(502), .decoding] {
            let flow = coordinator(StubAPIClient([.failure(failure)]))
            await flow.start()
            XCTAssertEqual(flow.screen, .retry, "\(failure)")
            XCTAssertEqual(flow.retryMessage, L10n.text(.genericError, "en"))
        }
    }

    func testTryAgainStartsAFreshInitiate() async {
        let stub = StubAPIClient([.fixture("initiate.response.invalid-transaction"), .fixture("initiate.response.success")])
        let flow = coordinator(stub)
        await flow.start()
        await flow.retry()
        XCTAssertEqual(flow.screen, .phone)
        XCTAssertEqual(stub.requests.map(\.action), [.initiate, .initiate])
        XCTAssertNil(stub.requests[1].sessionID)
        XCTAssertNotEqual(stub.requests[0].transactionID, stub.requests[1].transactionID)
    }

    func testInitiateWithAlreadySubscribedStillShowsPhone() async {
        let stub = StubAPIClient([.json(#"{"Error":3,"SessionID":"S","NextAction":{"Action":2}}"#)])
        let flow = coordinator(stub)
        await flow.start()
        XCTAssertEqual(flow.screen, .phone)
    }

    func testInitiateOpenContentFinishes() async {
        let flow = coordinator(StubAPIClient([.json(#"{"Error":3,"SessionID":"S","NextAction":{"Action":31}}"#)]))
        await flow.start()
        XCTAssertEqual(flow.screen, .finished)
        XCTAssertEqual(results, [.alreadySubscribed])
    }

    // MARK: Shells

    func testOnboardingThemeShowsIntroPagesThenPhone() async {
        let themes = OverridingThemeProvider(overrides: [:])
        let stub = StubAPIClient([.json(#"{"Error":0,"SessionID":"S","ThemeID":"shell-onboarding","NextAction":{"Action":2}}"#)])
        let flow = coordinator(stub, themes: themes)
        await flow.start()
        XCTAssertEqual(flow.document.template, .onboarding)
        XCTAssertEqual(flow.screen, .intro)
        let pages = flow.document.pages.count
        for index in 0..<pages {
            XCTAssertEqual(flow.screen, .intro)
            XCTAssertEqual(flow.introPageIndex, index)
            flow.advanceIntro()
        }
        XCTAssertEqual(flow.screen, .phone)
    }

    func testInterstitialThemeShowsOnePageThenPhone() async {
        let stub = StubAPIClient([.json(#"{"Error":0,"SessionID":"S","NextAction":{"Action":2,"Info":{"Theme":{"ThemeID":"shell-interstitial"}}}}"#)])
        let flow = coordinator(stub)
        await flow.start()
        XCTAssertEqual(flow.screen, .intro)
        flow.advanceIntro()
        XCTAssertEqual(flow.screen, .phone)
    }

    // MARK: sendPin

    func testSendPinSuccessMovesToPinScreen() async throws {
        let stub = StubAPIClient()
        let flow = await onPinScreen(stub)
        let request = try XCTUnwrap(stub.requests.last)
        XCTAssertEqual(request.action, .sendPin)
        XCTAssertEqual(request.phn, "96171020136")
        XCTAssertEqual(request.sessionID, "2deaa71c-b7c2-4120-a11e-3cc1f025227f")

        let pin = try XCTUnwrap(flow.pinContent)
        XCTAssertEqual(pin.pinLength, 5)
        XCTAssertTrue(pin.usesNumericKeyboard)
        XCTAssertEqual(pin.buttonTitle, "Confirm")
        XCTAssertEqual(pin.wrongNumberTitle, "Wrong number?")
        XCTAssertEqual(pin.validationMessage, "Please enter the correct PIN.")
        XCTAssertEqual(pin.resendTitle, "Resend pin", "decoded but not shown")
        XCTAssertEqual(pin.legalLinks.count, 2, "carried over from Initiate")
        XCTAssertNil(flow.inlineError, "\"OK\" is not shown")
    }

    func testInvalidPhoneIsRejectedLocally() async {
        let stub = StubAPIClient()
        let flow = await onPhoneScreen(stub)
        flow.phoneNumber = "12"
        await flow.submitPhone()
        XCTAssertEqual(flow.screen, .phone)
        XCTAssertNotNil(flow.inlineError)
        XCTAssertEqual(stub.requests.count, 1, "no sendPin sent")
    }

    func testPhnStripsLeadingZero() async throws {
        let stub = StubAPIClient()
        let flow = await onPhoneScreen(stub)
        flow.phoneNumber = "071020136"
        stub.enqueue(.fixture("sendpin.response.success"))
        await flow.submitPhone()
        XCTAssertEqual(stub.requests.last?.phn, "96171020136")
    }

    func testSendPinInvalidTransactionIsInlineThenRetryScreenAfterThree() async {
        let stub = StubAPIClient()
        let flow = await onPhoneScreen(stub)
        for attempt in 1...3 {
            stub.enqueue(.fixture("sendpin.response.invalid-transaction"))
            await flow.submitPhone()
            if attempt < 3 {
                XCTAssertEqual(flow.screen, .phone, "attempt \(attempt)")
                XCTAssertEqual(flow.inlineError, "Invalid TransactionID")
            }
        }
        XCTAssertEqual(flow.screen, .retry)
        XCTAssertEqual(flow.retryMessage, "Invalid TransactionID")
        let sendPins = stub.requests.filter { $0.action == .sendPin }
        XCTAssertEqual(Set(sendPins.map(\.transactionID)).count, 3)
        XCTAssertEqual(sendPins.first?.sessionID, "2deaa71c-b7c2-4120-a11e-3cc1f025227f")
        // The fixture echoes its own (non-empty) SessionID, which is then reused.
        XCTAssertEqual(sendPins.dropFirst().map(\.sessionID), ["ffebcc89-10cd-4b3f-b717-bfd4a1d2be38", "ffebcc89-10cd-4b3f-b717-bfd4a1d2be38"])
    }

    func testSendPinNetworkErrorIsInlineAndKeepsSession() async {
        let stub = StubAPIClient()
        let flow = await onPhoneScreen(stub)
        stub.enqueue(.failure(.httpStatus(500)))
        await flow.submitPhone()
        XCTAssertEqual(flow.screen, .phone)
        XCTAssertEqual(flow.inlineError, L10n.text(.networkError, "en"))
        XCTAssertEqual(flow.sessionID, "2deaa71c-b7c2-4120-a11e-3cc1f025227f")
    }

    // MARK: verifyPin

    func testWrongPinIsInlineAndClearsPin() async {
        let stub = StubAPIClient()
        let flow = await onPinScreen(stub)
        flow.pin = "12345"
        stub.enqueue(.fixture("verifypin.response.wrong-pin"))
        await flow.submitPin()
        XCTAssertEqual(flow.screen, .pin)
        XCTAssertEqual(flow.inlineError, "Please enter the correct PIN.")
        XCTAssertEqual(flow.pin, "")
        XCTAssertEqual(stub.requests.last?.pinCode, "12345")
    }

    func testWrongPinNeverTriggersRetryScreen() async {
        let stub = StubAPIClient()
        let flow = await onPinScreen(stub)
        for _ in 1...5 {
            flow.pin = "11111"
            stub.enqueue(.fixture("verifypin.response.wrong-pin"))
            await flow.submitPin()
        }
        XCTAssertEqual(flow.screen, .pin)
    }

    func testVerifyPinInvalidTransactionThreeTimesFallsBackToRetry() async {
        let stub = StubAPIClient()
        let flow = await onPinScreen(stub)
        for attempt in 1...3 {
            flow.pin = "12345"
            stub.enqueue(.fixture("verifypin.response.invalid-transaction"))
            await flow.submitPin()
            XCTAssertEqual(flow.screen, attempt < 3 ? .pin : .retry, "attempt \(attempt)")
        }
    }

    func testStopErrorStreakResetsAfterADifferentError() async {
        let stub = StubAPIClient()
        let flow = await onPinScreen(stub)
        for fixture in ["verifypin.response.invalid-transaction", "verifypin.response.invalid-transaction",
                        "verifypin.response.wrong-pin", "verifypin.response.invalid-transaction"] {
            flow.pin = "12345"
            stub.enqueue(.fixture(fixture))
            await flow.submitPin()
        }
        XCTAssertEqual(flow.screen, .pin, "the wrong-PIN reply broke the streak")
    }

    func testInvalidSessionGoesStraightToRetry() async {
        let stub = StubAPIClient()
        let flow = await onPinScreen(stub)
        flow.pin = "12345"
        stub.enqueue(.fixture("verifypin.response.invalid-session"))
        await flow.submitPin()
        XCTAssertEqual(flow.screen, .retry)
        XCTAssertEqual(flow.retryMessage?.hasPrefix("Sorry, an error occurred"), true)
    }

    func testIncompletePinIsRejectedLocally() async {
        let stub = StubAPIClient()
        let flow = await onPinScreen(stub)
        flow.pin = "12"
        await flow.submitPin()
        XCTAssertEqual(flow.inlineError, "Please enter the correct PIN.")
        XCTAssertFalse(stub.requests.contains { $0.action == .verifyPin })
    }

    func testVerifyPinOpenContentFinishesSubscribed() async {
        let stub = StubAPIClient()
        let flow = await onPinScreen(stub)
        flow.pin = "12345"
        stub.enqueue(.json(#"{"Error":0,"SessionID":"x","NextAction":{"Action":31}}"#))
        await flow.submitPin()
        XCTAssertEqual(flow.screen, .finished)
        XCTAssertEqual(results, [.subscribed])
    }

    func testVerifyPinSuccessWithoutNextActionIsSubscribed() async {
        let stub = StubAPIClient()
        let flow = await onPinScreen(stub)
        flow.pin = "12345"
        stub.enqueue(.json(#"{"Error":0,"SessionID":"","NextAction":{}}"#))
        await flow.submitPin()
        XCTAssertEqual(results, [.subscribed])
    }

    func testVerifyPinAlreadySubscribed() async {
        let stub = StubAPIClient()
        let flow = await onPinScreen(stub)
        flow.pin = "12345"
        stub.enqueue(.json(#"{"Error":3,"NextAction":{"Action":31}}"#))
        await flow.submitPin()
        XCTAssertEqual(results, [.alreadySubscribed])
    }

    // MARK: Navigation

    func testWrongNumberGoesBackKeepingNumberAndSession() async {
        let stub = StubAPIClient()
        let flow = await onPinScreen(stub)
        let requestCount = stub.requests.count
        let session = flow.sessionID
        XCTAssertNotNil(session)
        flow.editPhoneNumber()
        XCTAssertEqual(flow.screen, .phone)
        XCTAssertEqual(flow.phoneNumber, "71020136")
        XCTAssertEqual(stub.requests.count, requestCount, "no API call")

        stub.enqueue(.fixture("sendpin.response.success"))
        await flow.submitPhone()
        XCTAssertEqual(flow.screen, .pin)
        XCTAssertEqual(stub.requests.last?.sessionID, session)
    }

    func testCloseReportsCancelledOnce() async {
        let flow = await onPhoneScreen(StubAPIClient())
        flow.close()
        flow.close()
        XCTAssertEqual(results, [.cancelled])
        XCTAssertEqual(flow.screen, .finished)
    }

    func testCloseWhileRequestInFlightIgnoresTheLateResponse() async {
        let stub = StubAPIClient()
        let flow = await onPhoneScreen(stub)
        stub.enqueue(.fixture("sendpin.response.success"))
        let task = Task { await flow.submitPhone() }
        flow.close()
        await task.value
        XCTAssertEqual(results, [.cancelled])
        XCTAssertEqual(flow.screen, .finished)
    }

    func testInlineErrorAutoDismisses() async throws {
        let stub = StubAPIClient([.fixture("initiate.response.success")])
        let flow = FlowCoordinator(api: PaymentAPI(client: stub, initiateURL: testInitiateURL, apiURL: testAPIURL),
                                   factory: makeFactory(), themes: BundledThemeProvider(),
                                   validator: PhoneNumberValidator.shared, language: "en",
                                   initialDocument: BundledThemeProvider().resolve(themeID: nil),
                                   defaultDialCode: "961", errorDismissDelay: 0.05)
        await flow.start()
        flow.phoneNumber = "1"
        await flow.submitPhone()
        XCTAssertNotNil(flow.inlineError)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertNil(flow.inlineError)
    }
}
