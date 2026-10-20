# PaymentSDK

PaymentSDK is an iOS SDK for phone-number subscription. It shows a themed flow (phone number, then PIN) driven by the backend, and reports the outcome to your app. It works from both SwiftUI and UIKit.

- iOS 15+, Swift 5.9+, Swift Package Manager only
- Dependency: [PhoneNumberKit](https://github.com/PhoneNumberKit/PhoneNumberKit) (5.x)

## Installation

**Xcode:** File → Add Package Dependencies… → enter this repository's URL → add the `PaymentSDK` library to your app target.

**Package.swift:**

```swift
dependencies: [
    .package(url: "https://github.com/<org>/PaymentSDK.git", from: "1.0.0"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "PaymentSDK", package: "PaymentSDK"),
    ]),
]
```

## Configuration

Call `configure` once, as early as possible: in `application(_:didFinishLaunchingWithOptions:)`, or in your SwiftUI `App.init`.

```swift
import PaymentSDK

PaymentSDK.configure(
    PaymentSDKConfiguration(
        isOnLaunch: true,                       // see "Launch modes"
        packageName: nil,                       // default: Bundle.main.bundleIdentifier
        referrer: PaymentReferrer(
            naming: "",                         // Referrer.Native.Naming
            idOffer: -1,                        // Referrer.Native.IDOffer
            deeplink: "",                       // Referrer.Native.Deeplink
            country: nil                        // Referrer.Native.Country (omitted when nil/empty)
        ),
        isLoggingEnabled: false                 // PIN codes and full phone numbers are never logged
    )
) { result in
    // handle PaymentResult
}
```

| Property | Default |
|---|---|
| `initiateURL` (Initiate, Action "1") | `https://asarpluss.online` |
| `apiURL` (sendPin "2", verifyPin "3") | `https://d31e0jpxlj21ku.cloudfront.net` |
| `packageName` | host bundle identifier |
| `referrer` | naming `""`, idOffer `-1`, deeplink `""`, country `nil` |
| `isLoggingEnabled` | `false` |

The SDK sends `DeviceInfo` itself:

- `DeviceID`: `identifierForVendor`, stored in the Keychain on first use so it stays the same after a reinstall.
- `LangCode`: the device language from `Locale.preferredLanguages`, as two lowercase letters. This also sets the layout direction (right-to-left for Arabic).

## Launch modes

**`isOnLaunch: true`.** After `configure`, the SDK presents itself once, full-screen, on the top-most view controller. It waits until a foreground-active window scene with a key window exists. You don't need to call anything else.

**`isOnLaunch: false`.** Nothing appears until you ask for it.

UIKit:

```swift
PaymentSDK.present()                    // top-most view controller
PaymentSDK.present(from: someViewController)
```

SwiftUI:

```swift
@State private var showPayment = false

var body: some View {
    Button("Subscribe") { showPayment = true }
        .paymentSDK(isPresented: $showPayment) { result in
            // result for this presentation
        }
}
```

Every presentation starts a new session with a fresh Initiate call. Presenting while the SDK is already on screen does nothing. The modifier resets its binding to `false` when the flow ends.

## Handling the result

```swift
switch result {
case .subscribed:          // the PIN was verified
case .alreadySubscribed:   // backend Error 3
case .cancelled:           // the user closed the flow
case .failed(let error):   // configuration problem: .notConfigured, .noPresentingViewController
}
```

Network errors, wrong PINs and backend errors are handled inside the SDK's UI, which shows an inline message or a "Try again" screen. They are never reported as `.failed`. The callback runs on the main thread after the SDK has been dismissed.

Results go to the handler passed to `configure`. The one exception is a presentation started by the `.paymentSDK` modifier, whose results go to the modifier's own `onResult`.

## How the ThemeID picks a shell

1. The Initiate response carries a numeric theme ID, read from `NextAction.Info.Theme.ThemeID` or, if that is missing, the top-level `ThemeID`. Strings and numbers are both accepted.
2. The SDK loads `<id>.json` from its bundle. If that file is missing or invalid, it uses `default-theme.json`. If that also fails, it uses hard-coded default tokens.
3. The file's optional `template` field chooses the shell:

| `template` | Shell |
|---|---|
| missing or `"single"` | straight to the phone screen |
| `"onboarding"` | the `pages` intro pages, then the phone screen |
| `"interstitial"` | one full-screen page whose close button appears after `closeDelay` seconds, then the phone screen |

Exception: until the dashboard exists, steps 1 and 2 are skipped. The shell comes from `PaymentSDK.present(shell:)`: `.single`, `.onboarding` or `.interstitial`. With no `shell` (and on launch), it is `PaymentShell.fallback`, the interstitial.

Bundled themes: `default-theme`, `shell-single`, `shell-onboarding`, `shell-interstitial`, `625`, `644`, `813`, `837`, `858`, `873`. The ID in the current backend fixtures, `299`, is not bundled yet, so it falls back to `default-theme` (single).

Theme loading sits behind the internal `ThemeProviding` protocol. A provider that downloads themes from the backend can replace `BundledThemeProvider` without changing the flow.

## Adding a theme

1. Copy an existing file in `Sources/PaymentSDK/Resources/` (for example `644.json`) to `<ThemeID>.json`, such as `299.json`. The name must be the exact ID the backend sends.
2. Edit its tokens: `screen`, `header`, `field`, `button`, `text`, `spacing`. These sections are required; a file missing any of them is rejected and falls back to `default-theme`. These sections are optional: `formCard`, `field.floatingLabel`, `field.placeholderText`, `field.icons`, `blocks`.
3. To add intro pages, add `template` with `pages` (and `closeDelay` for an interstitial). Copy the shape from `shell-onboarding.json` or `shell-interstitial.json`:

```json
{
  "themeId": "299",
  "template": "interstitial",
  "closeDelay": 5,
  "pages": [
    {
      "imageUrl": "https://…/hero.jpg",
      "title":  { "en": "Special offer", "ar": "عرض خاص" },
      "text":   { "en": "Subscribe with your phone number.", "ar": "اشترك برقم هاتفك." },
      "button": { "en": "Continue", "ar": "متابعة" }
    }
  ],
  "version": 1,
  "screen": { … }, "header": { … }, "field": { … }, "button": { … }, "text": { … }, "spacing": { … },
  "blocks": []
}
```

4. Files in `Resources/` are bundled automatically (`.process("Resources")`), so you don't need to change `Package.swift`. Add the ID to `testEveryBundledThemeDecodes` in `ThemeSelectionTests` and run the tests.

Theme reference:

- Colours are `#RGB`, `#RRGGBB` or `#AARRGGBB`, with alpha first.
- `screen.background.type` is `color`, `image` or `video`. A `color` background with several `colors` becomes a slowly animated gradient.
- `button.background.type` is `solid`, `linear` or `radial`.
- Block types are `link`, `imageCarousel`, `cardGrid`, `logoRow`, `faq` and `imageGrid`.
- Block placements are `beforeForm`, `afterMiddleDisclaimer` and `afterForm` (the default).
- A block with `condition.serviceIds` is hidden, because the API doesn't send a service ID yet. `condition.country` is matched against `GeneralSettings.Country.Name`.
- `fontFamily` is used when that font is installed or can be registered from `fontUrl`, which can be a font file or Google Fonts CSS. Otherwise the system font is used.

## Development

```sh
xcodebuild -scheme PaymentSDK -destination 'generic/platform=iOS Simulator' build
xcodebuild test -scheme PaymentSDK -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

`swift build` alone targets macOS and fails, because the SDK uses UIKit. The tests use the captured responses in `Tests/PaymentSDKTests/Fixtures/` and never call the live backend.

### Example app

`Example/PaymentSDKExample1/` is a small host app:

- a "Present on launch" toggle, stored in UserDefaults, which takes effect on the next launch
- a "Present SDK" button (UIKit API) and a SwiftUI-modifier button
- the last `PaymentResult`

Open `Example/PaymentSDKExample1/PaymentSDKExample1.xcodeproj` and run the `PaymentSDKExample1` scheme. It uses this repository as a local package, so SDK changes show up on the next build. Close any other Xcode window that has the PaymentSDK package open first, or the dependency shows as missing.
