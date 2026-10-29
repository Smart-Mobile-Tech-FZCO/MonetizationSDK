# Architecture

How MonetizationSDK works inside. Read this before changing the code. For integrating the SDK, see [README.md](README.md). For what may be built next and the rules for changing anything, see [ROADMAP.md](ROADMAP.md).

## Overview

MonetizationSDK is one Swift package with one library product and module, `MonetizationSDK`. It targets iOS 15+ and has one dependency, PhoneNumberKit.

A presentation is one full-screen modal that runs a server-driven flow:

```
Initiate (Action "1") ──► [intro pages] ──► phone screen ──► sendPin (Action "2")
                                                                  │
                         result to host ◄── verifyPin (Action "3") ◄── PIN screen
```

The backend decides which screen comes next (`NextAction.Action`) and supplies the texts, header image, country and legal HTML. The SDK supplies the visual theme from bundled JSON files and handles errors on screen. The host app gets exactly one `MonetizationResult` per presentation.

## Source layout

```
Sources/MonetizationSDK/
  Public/       The whole public API. Nothing else is public.
  Flow/         Presentation, the state machine, and screen content.
  Networking/   Request envelope, response model, HTTP client.
  Device/       Device ID (Keychain) and DeviceInfo values.
  Theme/        Theme files: decoding, tokens, shell templates, fonts.
  UI/           SwiftUI views and the hosting controller.
  Resources/    Bundled theme JSONs and PrivacyInfo.xcprivacy.
Tests/MonetizationSDKTests/
  Fixtures/     Real backend requests and responses, used as test data.
  Support/      Stub API client and test helpers.
Example/        Host app for manual testing (Xcode project).
docs/           API contract (Postman), original fixtures, original build spec.
```

## Public API (`Public/`)

| Type | Role |
|---|---|
| `MonetizationSDK` | `configure(_:onResult:)` and `present(from:shell:)`. `@MainActor`. |
| `MonetizationConfiguration`, `MonetizationReferrer` | Everything the host can set. All fields have defaults. |
| `MonetizationShell` | `.single`, `.onboarding`, `.interstitial`. `MonetizationShell.fallback` is `.interstitial`. |
| `MonetizationResult`, `MonetizationError` | The outcome. `.failed` is only for integration errors. |
| `View.monetizationSDK(isPresented:onResult:)` | SwiftUI entry point. Calls the presenter. |

Keep this surface small. Adding a public symbol is an API change and needs approval (see ROADMAP.md).

## Flow layer (`Flow/`)

**`MonetizationPresenter`** (singleton, `@MainActor`) owns the configuration, the default result handler, and the single active presentation.
- `present` builds the object graph for one session (logger, `DeviceInfoProvider`, `PaymentAPI`, `BundledThemeProvider`, `FlowCoordinator`), wraps it in a `MonetizationHostingController`, presents it, and starts the flow.
- Launch mode (`isOnLaunch`) observes scene, window and app activation notifications and presents once, when a foreground-active scene has a key window whose top view controller is in the hierarchy. It retries briefly (up to 20 × 0.1 s) while the root controller is attached.
- `topMostViewController()` walks presented, navigation and tab controllers.

**`FlowCoordinator`** (`@MainActor`, `ObservableObject`) is the state machine for one session. Views only read its published state and call its methods.

States (`Screen`): `loading`, `intro`, `phone`, `pin`, `retry`, `finished`.

| Situation | Behaviour |
|---|---|
| Initiate succeeds (`Error` 0 or 3), `NextAction` 2 or 3 | Load the theme and go to the phone or PIN screen, through the intro pages if the shell has any. |
| Any step succeeds with `NextAction` 31 | Finish: `.subscribed` (`Error` 0) or `.alreadySubscribed` (`Error` 3). |
| verifyPin succeeds with no or unknown `NextAction` | Finish as above. The assumption lives in `resultForVerifyPinWithoutRoute`, because there is no real success sample yet. |
| Initiate fails (backend error, network, bad body) | Retry screen. "Try again" starts a new session. |
| sendPin/verifyPin fails, `NextAction` missing | Inline error on the same screen. verifyPin also clears the PIN. |
| sendPin/verifyPin fails with `NextAction` 7 | Inline error. On the 3rd consecutive failure of the same step, or when the response's `SessionID` is empty, go to the retry screen. |
| sendPin/verifyPin network failure | Inline network error. The session is kept. |
| Close (✕) anywhere | Finish with `.cancelled`. |

Inline errors dismiss themselves after 4 seconds. "Wrong number?" on the PIN screen returns to the phone screen in the same session, with the number kept.

**`ScreenContentMapper`** turns an `APIResponse` plus the accumulated `SessionContext` into `PhoneScreenContent` and `PinScreenContent`: labels, locked dial code, PIN length, disclaimers and legal links. A value in a later response replaces the stored one; a missing or empty value keeps it.

**`PhoneNumberValidator`** wraps PhoneNumberKit and builds `phn`: dial code plus national number, digits only, no `+` and no leading zero.

**`L10n`** holds the SDK's own fallback strings (English and Arabic) for when the backend sends none.

## Networking (`Networking/`)

- **`RequestFactory`** builds a `RequestEnvelope` for each action. Every call is a POST to the root path with this body:

  ```json
  {
    "DeviceInfo": { "PackageName": "com.example.app", "DeviceID": "UPPERCASE-UUID", "LangCode": "en" },
    "Request":    { "TransactionID": "…", "Action": "1" },
    "NewSDK": true,
    "Referrer": { "Native": { "Naming": "", "Version": 2, "IDOffer": -1, "Deeplink": "", "Country": "LB" } }
  }
  ```

  `Request` per action: Initiate `{ TransactionID, Action: "1" }`; sendPin `{ SessionID, TransactionID, Action: "2", phn }`; verifyPin `{ SessionID, TransactionID, Action: "3", PinCode }`. `Referrer.Native.Country` is omitted when empty. `RequestEncodingTests` enforces the exact keys.
- **IDs:** `TransactionID` is a new UUID on every request, retries included. `SessionID` comes from Initiate and is reused unchanged for the session; the coordinator never overwrites a stored one with an empty value. Initiate never sends a `SessionID`.
- **`PaymentAPIClient`** is the transport protocol; `URLSessionAPIClient` is the real one (POST, JSON, 30 s timeout, typed `APIClientError`). Tests replace it with a stub.
- **`PaymentAPI`** routes Initiate to `initiateURL` and sendPin/verifyPin to `apiURL`.
- **`APIResponse`** decodes leniently. Only `Error` is required, nested objects that fail to decode become `nil`, and IDs may be strings or numbers. Disclaimers arrive form-URL-encoded and are decoded by `HTMLDisclaimer`.
- **`SDKLogger`** prints one line per request and response when logging is on. It masks phone numbers and never prints PIN codes.

## Device (`Device/`)

- **`DeviceIdentity`** returns a stable device ID: the first `identifierForVendor` (or a new UUID) is saved in the Keychain and reused, so it survives reinstalls. If the Keychain fails, it falls back to UserDefaults.
- **`DeviceInfoProvider`** supplies `PackageName` (config override or bundle ID) and `LangCode` (2 lowercase letters from `Locale.preferredLanguages`, not `Locale.current`). The language also sets right-to-left layout.

## Theme system (`Theme/`)

A **theme file** is a JSON in `Resources/`. It has required token sections (`screen`, `header`, `field`, `button`, `text`, `spacing`), optional ones (`formCard`, `blocks`, and a few field extras), and optional shell fields: `template` (`single` | `onboarding` | `interstitial`), `pages` and `closeDelay`.

- **`ThemeProviding`** is the async protocol the coordinator uses to get a `PresentationDocument` for a theme ID. It exists so a provider that downloads themes can replace the bundled one without changing the flow.
- **`BundledThemeProvider`** loads `<id>.json` from `Bundle.module`. If that's missing or invalid, it uses `default-theme.json`, then hard-coded tokens. Only plain IDs (letters, digits, `-`, `_`) map to file names.
- **`forcedThemeID`**: when set, it replaces the backend's theme ID. Today the presenter always sets it to the requested shell's file (`shell-single`, `shell-onboarding` or `shell-interstitial`), so **the backend's `ThemeID` is currently ignored**. This is the hook the dashboard will replace (see ROADMAP.md).
- **`PresentationDocument`** is the decoded file: template, pages, close delay and `ThemeTokens`. An unknown `template` value makes the file invalid.
- **`ThemeFont`** registers a custom font from `fontUrl` (a font file or Google Fonts CSS) when it isn't installed. Otherwise the system font is used.

## UI (`UI/`)

- **`MonetizationHostingController`** is a full-screen `UIHostingController` that can't be swiped away and follows the theme's status bar style.
- **`MonetizationRootView`** switches on `flow.screen` and injects the theme and language into the environment.
- **Screens:** `LoadingView`, `RetryView`, `IntroPagesView` (onboarding pages or the interstitial with its countdown), `PhoneScreen` and `PinScreen`, both built on `FormScreen`.
- **`ThemedComponents`** has the shared pieces: backgrounds (color, gradient, image, looping video), buttons, fields, error banner, remote images with a cache.
- **`ThemeBlocksView`** renders optional theme blocks: links, image carousel, card grid, logo row, FAQ, image grid.
- **`HTMLDisclaimer`** decodes and renders the backend's HTML as attributed text. Terms and Privacy open in a sheet with a `WKWebView`.

Backgrounds and full-bleed images must not change the layout size. Use `.allowsHitTesting(false)` and sizes from the parent, not explicit frames larger than the screen.

## Concurrency

Strict concurrency checking is on for both targets. The presenter, the coordinator and all views are `@MainActor`. Network calls are awaited from the coordinator. After each `await`, the coordinator checks that the screen hasn't changed (closed or navigated away) before applying the response. Value types crossing actors are `Sendable`.

## Testing

- XCTest in `Tests/MonetizationSDKTests`. Tests never call the live backend. `StubAPIClient` replays the captured responses in `Fixtures/`.
- They cover request encoding (exact keys, `Action` as a string, no `SessionID` on Initiate), SessionID reuse, TransactionID uniqueness, DeviceInfo, response decoding for every fixture, disclaimer decoding, the coordinator's decision table, and theme and shell selection.

```sh
xcodebuild -scheme MonetizationSDK -destination 'generic/platform=iOS Simulator' build
xcodebuild test -scheme MonetizationSDK -destination 'platform=iOS Simulator,name=<an available iPhone>'
```

`swift build` alone targets macOS and fails, because the SDK uses UIKit.

The example app (`Example/MonetizationSDKExample`) uses this repository as a local package. Close other Xcode windows that have the package open before opening it.

## Adding a bundled theme

1. Copy a file in `Sources/MonetizationSDK/Resources/`, for example `644.json`, to `<ThemeID>.json`. The file name must be exactly the ID the backend sends.
2. Edit the tokens. A file missing a required section is rejected and falls back to `default-theme`.
3. For intro pages, set `template`, `pages` and, for an interstitial, `closeDelay`. Copy the shape from `shell-onboarding.json` or `shell-interstitial.json`. Page texts are localized objects: `{ "en": "…", "ar": "…" }`.
4. Add the ID to `testEveryBundledThemeDecodes` in `ThemeSelectionTests` and run the tests. `Resources/` is processed automatically, so `Package.swift` doesn't change.

Token reference:
- Colors are `#RGB`, `#RRGGBB` or `#AARRGGBB` (alpha first).
- `screen.background.type`: `color`, `image` or `video`. A `color` with several `colors` becomes a slowly animated gradient.
- `button.background.type`: `solid`, `linear` or `radial`.
- Block types: `link`, `imageCarousel`, `cardGrid`, `logoRow`, `faq`, `imageGrid`. Placements: `beforeForm`, `afterMiddleDisclaimer`, `afterForm` (default).
- A block with `condition.serviceIds` is hidden, because the API sends no service ID yet. `condition.country` is matched against `GeneralSettings.Country.Name`.

Bundled today: `default-theme`, `shell-single`, `shell-onboarding`, `shell-interstitial`, `625`, `644`, `813`, `837`, `858`, `873`.

## Key decisions

| Decision | Why |
|---|---|
| Swift Package Manager only, one module | Simplest integration. No CocoaPods. |
| Small public API; everything else `internal` | Internals can change without breaking host apps. |
| Recoverable errors stay in the UI; `.failed` only for integration errors | Host apps handle four outcomes and never retry network calls themselves. |
| Every presentation is a new session | Avoids stale `SessionID` and `TransactionID` state. |
| Themes are bundled JSON behind `ThemeProviding` | Works offline today; remote themes can be added later without touching the flow. |
| Lenient decoding | The backend's field shapes vary (string or number IDs, empty objects). |
