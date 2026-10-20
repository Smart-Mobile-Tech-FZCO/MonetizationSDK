import SwiftUI
import XCTest
@testable import PaymentSDK

final class ThemeSelectionTests: XCTestCase {

    private let provider = BundledThemeProvider()

    func testEveryBundledThemeDecodes() {
        for name in ["default-theme", "shell-single", "shell-onboarding", "shell-interstitial",
                     "625", "644", "813", "837", "858", "873"] {
            let data = BundledThemeProvider.loadFromModuleBundle(name)
            XCTAssertNotNil(data, "\(name).json is bundled")
            XCTAssertNotNil(data.flatMap { PresentationDocument.decode($0, sourceName: name) }, "\(name).json decodes")
        }
    }

    func testKnownNumericIDLoadsItsFile() {
        let document = provider.resolve(themeID: "644")
        XCTAssertEqual(document.sourceName, "644")
        XCTAssertEqual(document.theme.themeId, "644")
        XCTAssertEqual(document.template, .single, "no template field means single")
    }

    func testUnknownIDFallsBackToDefaultTheme() {
        let document = provider.resolve(themeID: "299")
        XCTAssertEqual(document.sourceName, "default-theme")
        XCTAssertEqual(document.template, .single)
    }

    func testMissingOrUnsafeIDsUseDefault() {
        XCTAssertEqual(provider.resolve(themeID: nil).sourceName, "default-theme")
        XCTAssertEqual(provider.resolve(themeID: "").sourceName, "default-theme")
        XCTAssertEqual(provider.resolve(themeID: "../625").sourceName, "default-theme")
        XCTAssertEqual(provider.resolve(themeID: "625.json").sourceName, "default-theme")
    }

    func testEachShellLoadsItsTemplate() {
        XCTAssertEqual(PaymentShell.fallback, .interstitial)
        for shell in PaymentShell.allCases {
            let document = BundledThemeProvider(forcedThemeID: shell.themeID).resolve(themeID: "644")
            XCTAssertEqual(document.sourceName, shell.themeID)
            XCTAssertEqual(document.template.rawValue, shell.rawValue)
        }
    }

    func testForcedThemeOverridesBackendID() {
        let forced = BundledThemeProvider(forcedThemeID: "shell-interstitial")
        for id in [nil, "", "299", "644"] {
            let document = forced.resolve(themeID: id)
            XCTAssertEqual(document.sourceName, "shell-interstitial")
            XCTAssertEqual(document.template, .interstitial)
        }
    }

    func testTemplateIsHonored() {
        let onboarding = provider.resolve(themeID: "shell-onboarding")
        XCTAssertEqual(onboarding.template, .onboarding)
        XCTAssertGreaterThan(onboarding.pages.count, 1)
        XCTAssertTrue(onboarding.hasIntro)
        XCTAssertEqual(onboarding.pages[0].title?.resolve("ar"), "العب بدون تنزيل")

        let interstitial = provider.resolve(themeID: "shell-interstitial")
        XCTAssertEqual(interstitial.template, .interstitial)
        XCTAssertEqual(interstitial.closeDelay, 5)
        XCTAssertEqual(interstitial.pages.count, 1)
    }

    func testNumericThemeWithTemplate() async {
        let themes = OverridingThemeProvider(overrides: ["900": Self.themeJSON(id: "900", extra: #""template": "interstitial", "closeDelay": 3,"#)])
        let document = await themes.document(forThemeID: "900")
        XCTAssertEqual(document.sourceName, "900")
        XCTAssertEqual(document.template, .interstitial)
        XCTAssertEqual(document.closeDelay, 3)
    }

    func testInvalidTemplateOrTokensFallBackToDefault() async {
        let themes = OverridingThemeProvider(overrides: [
            "901": Self.themeJSON(id: "901", extra: #""template": "carousel","#),
            "902": #"{"themeId": "902"}"#,
        ])
        let badTemplate = await themes.document(forThemeID: "901")
        XCTAssertEqual(badTemplate.sourceName, "default-theme")
        let badTokens = await themes.document(forThemeID: "902")
        XCTAssertEqual(badTokens.sourceName, "default-theme")
    }

    func testHardcodedFallbackWhenDefaultIsMissing() {
        let empty = BundledThemeProvider(loadData: { _ in nil })
        XCTAssertEqual(empty.resolve(themeID: "644").sourceName, "fallback")
        XCTAssertEqual(empty.resolve(themeID: "644").template, .single)
    }

    func testOptionalTokensAndBlocks() {
        XCTAssertNotNil(provider.resolve(themeID: "813").theme.formCard)
        XCTAssertEqual(provider.resolve(themeID: "813").theme.blocks.first?.kind, .imageCarousel)
        XCTAssertEqual(provider.resolve(themeID: "813").theme.blocks.first?.placement, .beforeForm)
        XCTAssertEqual(provider.resolve(themeID: "873").theme.blocks.map(\.kind), [.logoRow, .faq, .imageGrid])
        XCTAssertEqual(provider.resolve(themeID: "858").theme.screen.background.type, "video")
        XCTAssertEqual(provider.resolve(themeID: "625").theme.field.floatingLabel?.phoneText?.resolve("en"), "Mobile number")
        XCTAssertEqual(provider.resolve(themeID: "625").theme.blocks.first?.placement, .afterMiddleDisclaimer)
    }

    func testBlockConditions() {
        let block = provider.resolve(themeID: "625").theme.blocks[0]
        XCTAssertFalse(block.condition?.matches(countryISO: "NL") ?? true, "service-ID-restricted blocks stay hidden")
        let countryOnly = ThemeBlock.Condition(serviceIds: nil, country: "NL")
        XCTAssertTrue(countryOnly.matches(countryISO: "nl"))
        XCTAssertFalse(countryOnly.matches(countryISO: "LB"))
    }

    func testColorHexParsing() {
        func rgba(_ hex: String) -> [Int] {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(Color(hex: hex)).getRed(&r, green: &g, blue: &b, alpha: &a)
            return [r, g, b, a].map { Int(($0 * 255).rounded()) }
        }
        XCTAssertEqual(rgba("#FF0000"), [255, 0, 0, 255])
        XCTAssertEqual(rgba("#80B21F63"), [0xB2, 0x1F, 0x63, 0x80], "8 digits are AARRGGBB")
        XCTAssertEqual(rgba("#FFF"), [255, 255, 255, 255])
    }

    /// A minimal valid theme file with extra top-level fields.
    static func themeJSON(id: String, extra: String) -> String {
        let base = String(data: BundledThemeProvider.loadFromModuleBundle("default-theme")!, encoding: .utf8)!
        let withoutTemplate = base.replacingOccurrences(of: #""template": "single","#, with: "")
        return withoutTemplate.replacingOccurrences(of: #""themeId": "default","#, with: #""themeId": "\#(id)", \#(extra)"#)
    }
}

