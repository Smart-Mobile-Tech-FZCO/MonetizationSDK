# Build the PaymentSDK (iOS, Swift Package Manager)

You are working in a new, mostly empty repo for an **iOS payment SDK** that other iOS apps (SwiftUI and UIKit) will integrate. Build it as a **Swift Package** (no CocoaPods).

## Reference material — read these first

1. **API contract:** `docs/native-sdk-api-v2.postman_collection.json` (requests only).
2. **Real request/response samples:** `docs/fixtures/*.json`. They were captured from the live backend; field shapes may change slightly in future. Copy them into `Tests/PaymentSDKTests/Fixtures/` and use them as test fixtures. In `initiate.response.success.json`, the long Terms/Privacy HTML is trimmed; the real one is several KB of HTML.
   - `initiate.request.json`, `initiate.response.success.json`, `initiate.response.invalid-transaction.json`
   - `sendpin.request.json`, `sendpin.response.success.json`, `sendpin.response.invalid-transaction.json`
   - `verifypin.request.json`, `verifypin.response.wrong-pin.json`, `verifypin.response.invalid-session.json`, `verifypin.response.invalid-transaction.json`
3. **Working prototype app:** `/Users/ibrahimhassan/Downloads/SDKSample/AITrendStudio/` (read-only — never modify it). It was built to explore requirements and already implements most of this flow. Read before designing:
   - `SDUI/UserModels.swift`, `SDUI/UserClient.swift`: envelope, response model, error/next-action codes. **Where they disagree with the fixtures or this prompt, this prompt wins.**
   - `SDUI/PhoneAuthCoordinator.swift`: state machine (initiate → phone → PIN → done)
   - `SDUI/PresentationResolver.swift`, `SDUI/ThemeTokens.swift`: a theme ID selects a bundled JSON; its optional `template` (`single` | `onboarding` | `interstitial`) picks the shell; missing `template` = `single`
   - `SDUI/PresentationPagesView.swift`: onboarding pages + interstitial with `closeDelay` countdown
   - `SDUI/SDUIRenderer.swift`, `SDUI/SDUIModels.swift`, `SDUI/SDUIWebContent.swift`, `SDUI/UserScreenMapper.swift`: phone/PIN screens built from the API response, rendered with theme tokens, HTML disclaimers rendered as attributed text
   - `SDUI/PhoneNumberValidator.swift`, `SDUI/Country.swift`: phone validation (PhoneNumberKit)
   - `SDUI/UserInfoProvider.swift`, `SDUI/DeviceIdentity.swift`: DeviceInfo values
   - Theme/shell JSONs: `SDUI/default-theme.json`, `shell-single.json`, `shell-onboarding.json`, `shell-interstitial.json`, and numeric themes `625.json`, `644.json`, `813.json`, `837.json`, `858.json`, `873.json`

   The prototype has 3 debug buttons that force a shell. **The SDK has no such buttons**: the backend's initiate response decides.

   **Do not port** (prototype-only): `ContentView.swift`, `Home/*`, `ProfileView.swift`, `UserProfileStore.swift`, `AppleSignInManager.swift`, `AdjustManager.swift`, the resend-PIN API (Action 26), Apple/social sign-in, and the debug `previewId` override.

## What the SDK does

1. The host app configures the SDK once and either lets it launch itself at app launch (`isOnLaunch: true`) or presents it at any point in the user journey (`isOnLaunch: false`).
2. When launched, the SDK shows a loading state and calls **Initiate** (Action `"1"`). On success it:
   - stores `SessionID`
   - reads the theme ID, loads the matching bundled theme JSON, and shows its shell (see "Shell selection")
   - `onboarding` / `interstitial` show their intro pages first, then the phone screen. `single` goes straight to the phone screen.
3. **Phone screen** → user enters a number → validate → **sendPin** (Action `"2"`).
4. **PIN screen** → user enters the code → **verifyPin** (Action `"3"`).
5. Report the outcome to the host app and dismiss.

## Endpoints

- Initiate → `https://asarpluss.online`
- sendPin and verifyPin → `https://d31e0jpxlj21ku.cloudfront.net`

Both are POST to the root path. Make both URLs configurable, with these values as defaults.

## Request rules (strict — tests must enforce them)

Envelope for every call (compare with `docs/fixtures/*.request.json`):

```json
{
  "DeviceInfo": { "PackageName": "...", "DeviceID": "...", "LangCode": "en" },
  "Request":    { ...per action, see below... },
  "NewSDK": true,
  "Referrer": { "Native": { "Naming": "", "Version": 2, "IDOffer": -1, "Deeplink": "", "Country": "LB" } }
}
```

- **`Request` per action.** `Action` is always a **string**:
  - Initiate: `{ "TransactionID", "Action": "1" }`. No SessionID.
  - sendPin: `{ "SessionID", "TransactionID", "Action": "2", "phn" }`
  - verifyPin: `{ "SessionID", "TransactionID", "Action": "3", "PinCode" }`
- **`phn`**: the full number as digits only: country dial code + national number, no `+` and no leading zero (e.g. `"96171020136"`). Build it from the dial code (locked to `GeneralSettings.Country.Code` when the backend provides it) and the validated local number.
- **`DeviceInfo.DeviceID`**: fetched by the SDK and sent on **every** call, including Initiate. Use `UIDevice.current.identifierForVendor?.uuidString` (uppercase UUID, matches the fixtures). Persist the first value in the Keychain and reuse it afterwards so it stays stable even if IDFV changes after a reinstall. If IDFV is nil, generate a `UUID().uuidString` and persist that. Fall back to UserDefaults only if the Keychain fails.
- **`DeviceInfo.LangCode`**: the **device** language, 2-letter lowercase (`"en"`, `"ar"`, …). Take it from `Locale.preferredLanguages.first`, not `Locale.current`, which reflects the host app's localizations. Also use it for RTL layout.
- **`DeviceInfo.PackageName`**: host bundle identifier, overridable in config.
- **`SessionID`**: comes from the Initiate response and is **reused unchanged** for every later call in that SDK session. **Never overwrite a stored SessionID with an empty one**: error responses return `"SessionID": ""`. A new SDK launch, or a retry after an initiate failure, starts a new session.
- **`TransactionID`**: a **new unique value for every request**, including retries of the same step within one session (`UUID().uuidString`). The backend rejects a reused TransactionID with `"Invalid TransactionID"` (see the fixtures), so never cache or reuse one.
- **`Referrer.Native`** (merge of Postman v2 and the prototype; may change later, so keep it in one small type):
  - `Naming`: config, default `""`
  - `Version`: `2`
  - `IDOffer`: config, default `-1`
  - `Deeplink`: config, default `""`
  - `Country`: config, optional, **omitted** when nil/empty
- Encode with `JSONEncoder` and explicit `CodingKeys`, plus `encodeIfPresent` for optional fields. Key order doesn't matter; the prototype's hand-built string is not needed.

## Response handling

Model (decode leniently: every field optional except `Error`; IDs may be string or number):

```
Error: Int                      // 0 success, 3 already subscribed, other = error
MessageToShow: String           // may be "", "OK", or have a leading space — trim it
SessionID: String               // "" on many errors
Scheme: String                  // e.g. "error://" — decode, not used yet
ThemeID: String                 // top level; may be ""
SignupMethod: [String]          // ignore for now
NextAction: {                   // may be {} or have only "Action"
  Action: Int                   // 2 phone, 3 PIN, 7 error/stop, 31 open content
  Title: { Name, HeaderPic }    // header image URL lives here (not Service.HeaderPic as in the prototype)
  Info: {
    GeneralSettings: { Country: { Name: "LB", Code: "961" }, SupportedLanguages: [String] }
    Disclaimers: { headerInfo, middleInfo, footerInfo, OTPTopHeaderInfo }
    Theme: {
      ThemeID,
      TextBox: { Text, ErrorMSG, Length, PinLength: [Int], isNumeric },
      Button: { Text }, WrongNumber: { Text }, AskCodeAgain: { Text, CountDown },
      TermsAndConditions: { Text, Content(HTML) }, PrivacyPolicies: { Text, Content(HTML) }
    }
  }
}
```

**Disclaimers are form-URL-encoded HTML** (`+` means space, then percent-decoding, e.g. `%3ch4+style%3d...`). Decode them (`+` → space, then `removingPercentEncoding`) and render the HTML as styled text, the way the prototype's `SDUIWebContent` does. Show Terms & Conditions and Privacy Policy as tappable links that open their HTML `Content` in a sheet.

**Decision table:**

| Situation | Behaviour |
|---|---|
| `Error` 0 or 3, `NextAction.Action` 2 | Show phone screen (lock dial code from `GeneralSettings.Country.Code`; labels from `Theme`; header from `Title.HeaderPic`). |
| `Error` 0 or 3, `NextAction.Action` 3 | Show PIN screen. PIN length = `TextBox.Length`, else `PinLength[0]`, else 6. Numeric keyboard when `isNumeric != 0`. `TextBox.ErrorMSG` is the local validation message. |
| `Error` 0 or 3, `NextAction.Action` 31 | Flow complete → `.subscribed` (Error 0) or `.alreadySubscribed` (Error 3). |
| `Error` 0 after verifyPin with any other/missing next action | Treat as `.subscribed` (no success sample yet — keep this in one place so it's easy to change). |
| `Error` ≠ 0 on **Initiate** (any NextAction) or network/decoding failure on Initiate | **Retry screen**: themed full-screen error with `MessageToShow` (or a localized generic message) and a "Try again" button that starts a fresh Initiate with a new TransactionID and no SessionID. A close button returns `.cancelled`. |
| `Error` ≠ 0 on sendPin/verifyPin with `NextAction` `{}` or no Action (e.g. wrong PIN) | Stay on the same screen, show `MessageToShow` inline, clear the PIN field, and let the user retry. Each retry sends a new TransactionID with the same SessionID. |
| `Error` ≠ 0 on sendPin/verifyPin with `NextAction.Action` 7 | Show `MessageToShow` inline on the current screen and let the user retry the same step. If the same step fails with Action 7 three times in a row, or the message comes back with `SessionID: ""` (session invalid), switch to the **retry screen** (fresh Initiate). |
| Network error / non-2xx / undecodable body on sendPin/verifyPin | Inline error with a retry, keeping the session. |

Inline errors auto-dismiss after ~4 s, as in the prototype.

**PIN screen extras:** show `WrongNumber.Text` as a link that goes back to the phone screen in the same session, keeping the entered number (no API call). **Do not show** `AskCodeAgain` (resend) yet. Resend is out of scope, but keep the decoded value so it can be added later.

## Shell selection

- The backend sends a **numeric** theme ID (e.g. `"299"`), at `NextAction.Info.Theme.ThemeID`, with top-level `ThemeID` as a fallback. Accept string or number.
- Look up `<id>.json` in the SDK bundle (`Bundle.module`). If it's missing or invalid, use `default-theme.json`. If that fails too, use the hard-coded fallback tokens.
- The theme file's optional `"template"` field (`single` | `onboarding` | `interstitial`) chooses the shell; when it's absent, use `single`. `onboarding` and `interstitial` files carry `pages` and `closeDelay`, as in `shell-onboarding.json` / `shell-interstitial.json`.
- Port the prototype's numeric themes and the three shell files as SDK resources. Note: **`299` (the ID in the fixture) is not bundled yet**, so it falls back to `default-theme` (single). Add a short section to the README explaining how to add a new numeric theme with a template.
- Put theme loading behind a protocol so that downloading themes from the backend can be added later without changing the flow.

## Public API (keep it this small)

```swift
public struct PaymentSDKConfiguration {
    public var isOnLaunch: Bool
    public var initiateURL: URL           // default https://asarpluss.online
    public var apiURL: URL                // default https://d31e0jpxlj21ku.cloudfront.net (sendPin + verifyPin)
    public var packageName: String?       // default Bundle.main.bundleIdentifier
    public var referrer: PaymentReferrer  // naming "", idOffer -1, deeplink "", country nil
    public var isLoggingEnabled: Bool     // default false; never log PinCode or full phone numbers
}

public enum PaymentResult {
    case subscribed
    case alreadySubscribed
    case cancelled                    // user closed the flow at any step
    case failed(PaymentSDKError)      // only for unrecoverable configuration errors; recoverable errors stay in the UI
}

@MainActor
public enum PaymentSDK {
    public static func configure(_ config: PaymentSDKConfiguration,
                                 onResult: @escaping (PaymentResult) -> Void)
    public static func present(from viewController: UIViewController? = nil)  // nil = top-most VC
}

extension View {   // SwiftUI convenience
    public func paymentSDK(isPresented: Binding<Bool>,
                           onResult: @escaping (PaymentResult) -> Void) -> some View
}
```

`isOnLaunch: true`: after `configure(...)` (called from `application(_:didFinishLaunchingWithOptions:)` or the SwiftUI `App.init`), the SDK presents itself once, full-screen, on the top-most view controller as soon as a foreground-active window scene with a key window exists. `false`: nothing happens until `present` or the SwiftUI modifier is used. Presenting while already presented is a no-op. Every presentation is a fresh session (new Initiate).

## Package and engineering requirements

- Package / library product / module: `PaymentSDK`. Minimum **iOS 15** (not 26.x like the prototype), Swift 5.9+, SwiftUI internally, UIKit-friendly entry points.
- Resources (theme JSONs, `PrivacyInfo.xcprivacy`) in `Sources/PaymentSDK/Resources/`, loaded via `Bundle.module`, never `Bundle.main`.
- Only the public API above is `public`; everything else is `internal`.
- Dependencies: PhoneNumberKit via SPM only. **No Adjust**; referrer values come from config.
- Networking: `URLSession` + `async/await`, 30 s timeout, typed errors, behind a protocol so tests can stub responses with the fixtures.
- The flow coordinator is `@MainActor` and has no data races.
- Privacy manifest: declare UserDefaults and Keychain use, no tracking, and phone number collected for app functionality.
- **Tests** (`Tests/PaymentSDKTests`, XCTest), at minimum:
  - Each action's encoded request has exactly the keys shown in the fixtures, plus the merged referrer; `Action` is a string; Initiate has no `SessionID`; sendPin uses `phn`.
  - SessionID is reused across calls and is not overwritten by an empty one.
  - TransactionID is unique on every call, including retries.
  - LangCode is 2 lowercase letters from `preferredLanguages`. DeviceID is stable across calls.
  - Every fixture response decodes, including `NextAction: {}` and missing `Info`.
  - Disclaimer decoding turns `%3ch4+style...` into `<h4 style...`.
  - The coordinator follows the decision table for every fixture (initiate fail → retry screen; wrong PIN → inline; invalid TransactionID → inline then fallback after 3; success transitions 2 → 3).
  - Shell selection: known numeric ID, unknown `299` → default, `template` honored.
- **Example host app** in `Example/` (the Xcode project is created by me; you write its sources): an `isOnLaunch` toggle (stored in UserDefaults, takes effect on next launch), a "Present SDK" button, and a label with the last `PaymentResult`.
- `README.md`: installation (Xcode → Add Package Dependency / `Package.swift`), configuration, both launch modes, result handling, how ThemeID picks a shell, and how to add a theme.

## Still unknown — handle defensively, list in your final summary

- No sample of a **successful verifyPin** response yet (assumed: Error 0 with NextAction 31 or nothing).
- The meaning of NextAction **7** beyond "error". Treated as above.
- Whether `Scheme` and `SignupMethod` will be used.

## How to work

1. Read the reference files and fixtures. Then reply with your file/folder layout, the final public API, and anything in this prompt that conflicts with the fixtures. **Wait for my OK before writing code.**
2. Implement in small, tested steps: models + client + tests → coordinator + tests → UI (loading, retry, shells, phone, PIN) → public API + launch modes → example app → README.
3. Build and test often: `xcodebuild -scheme PaymentSDK -destination 'generic/platform=iOS Simulator' build` and `xcodebuild test -scheme PaymentSDK -destination 'platform=iOS Simulator,name=<an available iPhone>'` (`swift build` alone targets macOS and will fail on UIKit).
4. Don't call the live backend from tests. A manual smoke test from the example app is fine.
5. When finished, summarize what was built, how to run the example app, and what's still open.
