# PaymentSDK for iOS

PaymentSDK adds a phone-number subscription flow to your iOS app. It shows a full-screen, themed flow (an optional intro screen, then phone number, then PIN), talks to the subscription backend for you, and tells your app the result. It works from SwiftUI and UIKit.

- iOS 15 or later, Swift 5.9 or later, Xcode 15 or later
- Swift Package Manager only
- Brings in one dependency: [PhoneNumberKit](https://github.com/PhoneNumberKit/PhoneNumberKit) 5.x

## Before you start

**Your app's bundle identifier must be registered with the subscription backend.** The SDK sends it as `PackageName` with every request. If it isn't registered, the backend refuses the request and the SDK only shows "Sorry, an error occurred … please try again later" with a **Try again** button. Ask the backend team to register your bundle ID, or to give you a registered package name to pass in `packageName` (see [Configuration](#configuration)).

## 1. Add the package

**In Xcode:** File → Add Package Dependencies… → paste the repository URL:

```
https://github.com/Smart-Mobile-Tech-FZCO/PaymentSDK-iOS.git
```

Choose **Up to Next Major Version** from `1.0.0`, then add the **PaymentSDK** library to your app target.

**Or in `Package.swift`:**

```swift
dependencies: [
    .package(url: "https://github.com/Smart-Mobile-Tech-FZCO/PaymentSDK-iOS.git", from: "1.0.0"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "PaymentSDK", package: "PaymentSDK-iOS"),
    ]),
]
```

If the repository is private, add a GitHub account with access to it in Xcode → Settings → Accounts first, or package resolution fails.

## 2. Configure it once at startup

Call `PaymentSDK.configure` once, as early as possible. Everything except the result handler has a default.

**SwiftUI:**

```swift
import PaymentSDK
import SwiftUI

@main
struct MyApp: App {
    init() {
        PaymentSDK.configure(PaymentSDKConfiguration(isOnLaunch: true)) { result in
            // See "4. Handle the result"
        }
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

**UIKit:**

```swift
import PaymentSDK

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    PaymentSDK.configure(PaymentSDKConfiguration(isOnLaunch: true)) { result in
        // See "4. Handle the result"
    }
    return true
}
```

### Configuration

```swift
PaymentSDKConfiguration(
    isOnLaunch: false,          // true: the SDK opens by itself when the app starts
    packageName: nil,           // nil: your app's bundle identifier
    referrer: PaymentReferrer(
        naming: "",             // campaign naming
        idOffer: -1,            // offer ID
        deeplink: "",           // deeplink that brought the user in
        country: "LB"           // ISO country code; leave nil if unknown
    ),
    isLoggingEnabled: true      // prints request/response summaries; turn off for release
)
```

| Property | Default | What it does |
|---|---|---|
| `isOnLaunch` | `false` | Opens the SDK automatically once, when the app starts. |
| `packageName` | your bundle ID | The package name sent to the backend. It must be registered there. |
| `referrer` | naming `""`, idOffer `-1`, deeplink `""`, country `nil` | Attribution values sent with every request. |
| `isLoggingEnabled` | `false` | Console logs prefixed `[PaymentSDK]`. PIN codes and full phone numbers are never logged. |
| `initiateURL` | `https://asarpluss.online` | Backend for starting a session. Only change it if the backend team tells you to. |
| `apiURL` | `https://d31e0jpxlj21ku.cloudfront.net` | Backend for sending and verifying the PIN. Only change it if told to. |

The SDK collects the rest itself: a device ID (kept in the Keychain so it stays the same across reinstalls) and the device language (which also switches the layout to right-to-left for Arabic).

## 3. Show the flow

You have three ways to show it. Pick one per entry point.

**Automatically at launch.** Configure with `isOnLaunch: true` and do nothing else. The SDK waits until your first screen is on screen, then presents itself full-screen once per app launch.

**From UIKit, whenever you want:**

```swift
PaymentSDK.present()                         // from the top-most view controller
PaymentSDK.present(from: someViewController) // from a specific one
PaymentSDK.present(shell: .onboarding)       // with a specific intro style (see below)
```

**From SwiftUI, with a binding:**

```swift
struct PaywallButton: View {
    @State private var showPayment = false

    var body: some View {
        Button("Subscribe") { showPayment = true }
            .paymentSDK(isPresented: $showPayment) { result in
                // Result of this presentation only
            }
    }
}
```

The binding goes back to `false` when the flow ends.

Every presentation starts a fresh session. Calling `present` while the SDK is already on screen does nothing.

### Intro styles (shells)

The flow can open with an intro before the phone screen. Pick it with `shell:`:

| Shell | What the user sees |
|---|---|
| `.interstitial` (default) | One full-screen offer page. Its close button appears after a short countdown. **Continue** goes to the phone screen. |
| `.onboarding` | A few swipeable intro pages with **Next**, then the phone screen. |
| `.single` | Straight to the phone screen. |

Launch mode and the SwiftUI modifier always use the default, `.interstitial`. A future backend dashboard will choose the shell remotely; until then, your app chooses it.

## 4. Handle the result

Your handler receives exactly one result per presentation, on the main thread, after the SDK has closed.

```swift
PaymentSDK.configure(config) { result in
    switch result {
    case .subscribed:
        // The user confirmed the PIN. Unlock the content.
    case .alreadySubscribed:
        // The user already had a subscription. Unlock the content.
    case .cancelled:
        // The user closed the flow.
    case .failed(let error):
        // Integration problem, see below.
    }
}
```

`.failed` only means the integration is wrong:

| Error | Cause | Fix |
|---|---|---|
| `.notConfigured` | `present` or `.paymentSDK` was used before `configure`. | Call `configure` at startup. |
| `.noPresentingViewController` | No visible view controller to present from. | Call `present` once your UI is on screen, or pass `from:`. |

Network errors, wrong PINs and backend errors are not reported to your app. The SDK handles them on screen with a message or a **Try again** button.

Where results go: presentations started by `present` or by launch mode report to the handler passed to `configure`. Presentations started by `.paymentSDK` report to the modifier's own `onResult`.

## Checklist

- [ ] Your bundle ID (or the `packageName` you pass) is registered with the backend.
- [ ] `configure` runs once at startup, before any `present`.
- [ ] Your handler unlocks content for both `.subscribed` and `.alreadySubscribed`.
- [ ] You tested on a simulator or device with logging on and saw `[PaymentSDK] ← Action 1 Error=0` in the console.

## Troubleshooting

| Symptom | Cause |
|---|---|
| Always "Sorry, an error occurred … please try again later" | The package name isn't registered with the backend. Check the console with `isLoggingEnabled: true`: `Error=1` on Action 1 confirms it. |
| Nothing appears with `isOnLaunch: true` | `configure` ran after the app was already active, or was never called. Call it in `App.init` or `didFinishLaunchingWithOptions`. |
| Nothing appears on `present()` | The SDK is already on screen, or your handler received `.failed`. |
| Xcode says the package can't be resolved | The repository is private and Xcode has no GitHub account with access. |

## Privacy

The SDK ships its own privacy manifest (`PrivacyInfo.xcprivacy`). It declares the phone number and device ID it collects for app functionality, its use of UserDefaults, and no tracking. Xcode merges it into your app's privacy report automatically.

## Example app

`Example/PaymentSDKExample1/` in this repository is a working host app. Open `PaymentSDKExample1.xcodeproj` and run the `PaymentSDKExample1` scheme on an iOS simulator. It shows launch mode, both presentation APIs, one button per shell, and the last result.

## More

- [CHANGELOG.md](CHANGELOG.md): what changed in each version
- [ARCHITECTURE.md](ARCHITECTURE.md): how the SDK works inside, for maintainers
- [ROADMAP.md](ROADMAP.md): what's planned, and the rules for changing the SDK
