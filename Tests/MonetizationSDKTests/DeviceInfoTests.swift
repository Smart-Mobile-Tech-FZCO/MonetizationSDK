import XCTest
@testable import MonetizationSDK

final class DeviceInfoTests: XCTestCase {

    func testLangCodeIsTwoLowercaseLettersFromPreferredLanguages() {
        XCTAssertEqual(DeviceInfoProvider.languageCode(from: ["ar-LB", "en-US"]), "ar")
        XCTAssertEqual(DeviceInfoProvider.languageCode(from: ["EN-us"]), "en")
        XCTAssertEqual(DeviceInfoProvider.languageCode(from: ["zh-Hans-CN"]), "zh")
        XCTAssertEqual(DeviceInfoProvider.languageCode(from: ["fr_FR"]), "fr")
        XCTAssertEqual(DeviceInfoProvider.languageCode(from: []), "en")
        XCTAssertEqual(DeviceInfoProvider.languageCode(from: ["fil-PH"]), "en", "non-2-letter codes fall back")
    }

    func testProviderUsesPreferredLanguagesNotCurrentLocale() {
        let provider = DeviceInfoProvider(identity: DeviceIdentity(primary: InMemoryDeviceIDStore(),
                                                                   fallback: InMemoryDeviceIDStore(),
                                                                   vendorID: { "abc" }),
                                          packageNameOverride: nil,
                                          preferredLanguages: { ["ar-EG"] },
                                          bundleIdentifier: { "com.host" })
        let info = provider.deviceInfo()
        XCTAssertEqual(info.langCode, "ar")
        XCTAssertTrue(info.langCode.allSatisfy { $0.isLowercase } && info.langCode.count == 2)
        XCTAssertEqual(info.packageName, "com.host")
        XCTAssertTrue(DeviceInfoProvider.isRightToLeft("ar"))
        XCTAssertFalse(DeviceInfoProvider.isRightToLeft("en"))
    }

    func testPackageNameOverride() {
        let provider = DeviceInfoProvider(identity: DeviceIdentity(primary: InMemoryDeviceIDStore(),
                                                                   fallback: InMemoryDeviceIDStore()),
                                          packageNameOverride: "com.override",
                                          bundleIdentifier: { "com.host" })
        XCTAssertEqual(provider.packageName, "com.override")
    }

    func testDeviceIDUsesIDFVUppercasedAndPersistsIt() {
        let keychain = InMemoryDeviceIDStore()
        let identity = DeviceIdentity(primary: keychain, fallback: InMemoryDeviceIDStore(),
                                      vendorID: { "cbb7675d-9da3-4d7c-bd7b-b0cd720e2065" })
        XCTAssertEqual(identity.deviceID, "CBB7675D-9DA3-4D7C-BD7B-B0CD720E2065")
        XCTAssertEqual(keychain.value, "CBB7675D-9DA3-4D7C-BD7B-B0CD720E2065")
    }

    func testDeviceIDIsStableAcrossCallsAndIDFVChanges() {
        let keychain = InMemoryDeviceIDStore()
        var idfv = "11111111-1111-1111-1111-111111111111"
        let first = DeviceIdentity(primary: keychain, fallback: InMemoryDeviceIDStore(), vendorID: { idfv }).deviceID

        idfv = "22222222-2222-2222-2222-222222222222" // e.g. after a reinstall
        let identity = DeviceIdentity(primary: keychain, fallback: InMemoryDeviceIDStore(), vendorID: { idfv })
        XCTAssertEqual(identity.deviceID, first)
        XCTAssertEqual(identity.deviceID, first)
    }

    func testDeviceIDWhenIDFVIsNil() throws {
        let keychain = InMemoryDeviceIDStore()
        let id = DeviceIdentity(primary: keychain, fallback: InMemoryDeviceIDStore(), vendorID: { nil }).deviceID
        XCTAssertNotNil(UUID(uuidString: id))
        XCTAssertEqual(id, id.uppercased())
        XCTAssertEqual(keychain.value, id)
    }

    func testFallsBackToUserDefaultsWhenKeychainFails() {
        let keychain = InMemoryDeviceIDStore(failsWrites: true)
        let defaults = InMemoryDeviceIDStore()
        let id = DeviceIdentity(primary: keychain, fallback: defaults, vendorID: { "AAAA" }).deviceID
        XCTAssertEqual(defaults.value, id)

        // Next launch: keychain still empty, fallback value is reused.
        let again = DeviceIdentity(primary: keychain, fallback: defaults, vendorID: { "BBBB" }).deviceID
        XCTAssertEqual(again, id)
    }

    func testUserDefaultsStoreRoundTrip() throws {
        let suite = "MonetizationSDKTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsDeviceIDStore(defaults: defaults)
        XCTAssertNil(store.read())
        XCTAssertTrue(store.write("ID-1"))
        XCTAssertEqual(store.read(), "ID-1")
    }
}
