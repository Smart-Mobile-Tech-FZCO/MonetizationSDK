import XCTest
@testable import PaymentSDK

final class ResponseDecodingTests: XCTestCase {

    func testEveryFixtureDecodes() {
        for name in Fixture.allResponses {
            XCTAssertNoThrow(try Fixture.response(name), name)
        }
    }

    func testInitiateSuccess() throws {
        let response = try Fixture.response("initiate.response.success")
        XCTAssertEqual(response.error, 0)
        XCTAssertNil(response.message, "empty MessageToShow becomes nil")
        XCTAssertEqual(response.sessionID, "2deaa71c-b7c2-4120-a11e-3cc1f025227f")
        XCTAssertEqual(response.scheme, "error://")
        XCTAssertEqual(response.signupMethod, [])
        XCTAssertEqual(response.resolvedThemeID, "299")

        let next = try XCTUnwrap(response.nextAction)
        XCTAssertEqual(next.action, 2)
        XCTAssertEqual(next.title?.name, "Laki")
        XCTAssertEqual(next.title?.headerPic?.hasPrefix("https://asarpluss.online/Themes/HeaderPicsLive/"), true)
        XCTAssertEqual(next.info?.generalSettings?.country?.name, "LB")
        XCTAssertEqual(next.info?.generalSettings?.country?.code, "961")
        XCTAssertEqual(next.info?.generalSettings?.supportedLanguages, ["en"])
        XCTAssertEqual(next.info?.theme?.textBox?.text, "Phone number")
        XCTAssertEqual(next.info?.theme?.button?.text, "Subscribe")
        XCTAssertEqual(next.info?.theme?.termsAndConditions?.text, "Terms & Conditions")
        XCTAssertEqual(next.info?.theme?.privacyPolicies?.content?.hasPrefix("<div"), true)
        XCTAssertNotNil(next.info?.disclaimers?.headerInfo)
    }

    func testSendPinSuccess() throws {
        let response = try Fixture.response("sendpin.response.success")
        XCTAssertEqual(response.message, "OK")
        XCTAssertNil(response.resolvedThemeID, "empty ThemeID")
        let next = try XCTUnwrap(response.nextAction)
        XCTAssertEqual(next.action, 3)
        XCTAssertNil(next.title?.name)
        XCTAssertNotNil(next.title?.headerPic)
        XCTAssertNil(next.info?.generalSettings)

        let theme = try XCTUnwrap(next.info?.theme)
        XCTAssertEqual(theme.textBox?.effectivePinLength, 5)
        XCTAssertEqual(theme.textBox?.usesNumericKeyboard, true)
        XCTAssertEqual(theme.textBox?.errorMSG?.nonEmptyTrimmed, "Please enter the correct PIN.")
        XCTAssertEqual(theme.wrongNumber?.text, "Wrong number?")
        XCTAssertEqual(theme.askCodeAgain?.text, "Resend pin")
        XCTAssertEqual(theme.askCodeAgain?.countDown, 60)
        XCTAssertEqual(theme.button?.text, "Confirm")
    }

    func testEmptyNextActionAndMissingInfo() throws {
        let wrongPin = try Fixture.response("verifypin.response.wrong-pin")
        XCTAssertEqual(wrongPin.error, 1)
        XCTAssertNotNil(wrongPin.nextAction, "{} decodes to an empty object")
        XCTAssertNil(wrongPin.nextAction?.action)
        XCTAssertNil(wrongPin.nextAction?.info)
        XCTAssertEqual(wrongPin.message, "Please enter the correct PIN.", "leading space trimmed")

        let invalid = try Fixture.response("verifypin.response.invalid-session")
        XCTAssertEqual(invalid.nextAction?.action, 7)
        XCTAssertNil(invalid.nextAction?.info)
        XCTAssertEqual(invalid.sessionID, "")
    }

    func testNumericIDsAndStringErrorAreAccepted() throws {
        let json = """
        {"Error":"0","SessionID":123,"ThemeID":644,
         "NextAction":{"Action":"2","Info":{"Theme":{"ThemeID":625,"TextBox":{"Length":"4","isNumeric":false}},
                                            "GeneralSettings":{"Country":{"Name":"LB","Code":961}}}}}
        """
        let response = try JSONDecoder().decode(APIResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.error, 0)
        XCTAssertEqual(response.sessionID, "123")
        XCTAssertEqual(response.themeID, "644")
        XCTAssertEqual(response.nextAction?.action, 2)
        XCTAssertEqual(response.resolvedThemeID, "625", "NextAction.Info.Theme.ThemeID wins")
        XCTAssertEqual(response.nextAction?.info?.generalSettings?.country?.code, "961")
        XCTAssertEqual(response.nextAction?.info?.theme?.textBox?.effectivePinLength, 4)
        XCTAssertEqual(response.nextAction?.info?.theme?.textBox?.usesNumericKeyboard, false)
    }

    func testMalformedNestedObjectsAreIgnored() throws {
        let json = #"{"Error":1,"NextAction":{"Action":7,"Info":"oops","Title":[]},"SignupMethod":"x"}"#
        let response = try JSONDecoder().decode(APIResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.nextAction?.action, 7)
        XCTAssertNil(response.nextAction?.info)
        XCTAssertNil(response.signupMethod)
    }

    func testMissingErrorFailsDecoding() {
        XCTAssertThrowsError(try JSONDecoder().decode(APIResponse.self, from: Data(#"{"MessageToShow":"x"}"#.utf8)))
    }

    func testPinLengthFallbacks() throws {
        func length(_ textBox: String) throws -> Int? {
            let json = #"{"Error":0,"NextAction":{"Info":{"Theme":{"TextBox":"# + textBox + "}}}}"
            return try JSONDecoder().decode(APIResponse.self, from: Data(json.utf8))
                .nextAction?.info?.theme?.textBox?.effectivePinLength
        }
        XCTAssertEqual(try length(#"{"Length":5,"PinLength":[4]}"#), 5)
        XCTAssertEqual(try length(#"{"PinLength":[4]}"#), 4)
        XCTAssertEqual(try length(#"{"Length":0}"#), 6)
        XCTAssertEqual(try length(#"{}"#), 6)
    }
}
