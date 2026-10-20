# Changelog

Core changes to PaymentSDK, by version. Only changes that matter to apps integrating the SDK or to its roadmap are listed: new capabilities, API changes, behaviour changes and important fixes. Internal refactors and small fixes are not.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/): a major version for breaking public API changes, a minor version for new features, a patch version for fixes.

## [Unreleased]

Nothing yet.

## [1.0.0] - 2026-10-20

First release.

### Added

- Phone-number subscription flow: Initiate, then phone number (sendPin), then PIN (verifyPin), driven by the backend's `NextAction`.
- Public API: `PaymentSDK.configure(_:onResult:)`, `PaymentSDK.present(from:shell:)`, the SwiftUI modifier `.paymentSDK(isPresented:onResult:)`, `PaymentSDKConfiguration`, `PaymentReferrer`, `PaymentResult` and `PaymentSDKError`.
- Two launch modes: automatic presentation at app launch (`isOnLaunch: true`) or on demand.
- Three intro shells, selectable per presentation with `PaymentShell`: `.interstitial` (default), `.onboarding` and `.single`.
- Bundled themes with server-driven texts, header image, country lock and legal HTML (Terms and Privacy).
- On-screen error handling: inline errors with retry, a full-screen "Try again" for failed sessions. Only integration errors reach the host as `.failed`.
- Stable device ID stored in the Keychain, device-language detection with right-to-left layout, configurable referrer values.
- Privacy manifest (`PrivacyInfo.xcprivacy`).
- Example host app.

### Known limitations

- The backend dashboard that will choose the shell and the launch behaviour doesn't exist yet. Until it does, the host app chooses the shell, and the backend's `ThemeID` is ignored.
- Resending the PIN ("Ask code again") is not available.
- No real sample of a successful verifyPin response exists yet. The SDK assumes `Error` 0 means subscribed.
