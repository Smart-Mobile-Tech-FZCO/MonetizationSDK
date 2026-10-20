import XCTest
@testable import PaymentSDK

final class DisclaimerDecodingTests: XCTestCase {

    func testFormURLDecoding() {
        XCTAssertEqual(
            HTMLDisclaimer.formURLDecode("%3ch4+style%3d%22text-align%3a+center%22%3eEnter+your+phone+number%3c%2fh4%3e"),
            #"<h4 style="text-align: center">Enter your phone number</h4>"#
        )
        XCTAssertTrue(HTMLDisclaimer.formURLDecode("%3ch4+style...").hasPrefix("<h4 style"))
    }

    func testPlainHTMLIsLeftAlone() {
        let html = #"<p>1+1 = 2</p>"#
        XCTAssertEqual(HTMLDisclaimer.formURLDecode(html), html)
    }

    func testFixtureDisclaimersRenderAsText() throws {
        let response = try Fixture.response("initiate.response.success")
        let header = try XCTUnwrap(HTMLDisclaimer.decodedNonEmpty(response.nextAction?.info?.disclaimers?.headerInfo))
        XCTAssertEqual(HTMLDisclaimer.plainText(header), "Enter your phone number")

        let footer = try XCTUnwrap(HTMLDisclaimer.decodedNonEmpty(response.nextAction?.info?.disclaimers?.footerInfo))
        XCTAssertTrue(footer.contains("<font face=\"Arial\">"))
        XCTAssertTrue(HTMLDisclaimer.plainText(footer).contains("you can unsubscribe by send wa to 1124."))

        XCTAssertNil(HTMLDisclaimer.decodedNonEmpty(response.nextAction?.info?.disclaimers?.middleInfo), "empty")
    }

    func testRenderingKeepsLinksAndLineBreaks() {
        let rendered = HTMLDisclaimer.attributedString(from: #"<p>One</p><p>Two <a href="https://x.test">link</a></p>"#)
        XCTAssertEqual(String(rendered.characters), "One\nTwo link")
        XCTAssertTrue(rendered.runs.contains { $0[AttributeScopes.FoundationAttributes.LinkAttribute.self] == URL(string: "https://x.test") })
    }

    func testScriptsAreDropped() {
        XCTAssertEqual(HTMLDisclaimer.plainText("<script>alert(1)</script>Hi &amp; bye"), "Hi & bye")
    }
}
