# Roadmap

The plan for PaymentSDK, and the rules for changing it. **Any AI assistant (Claude Code or other) or contributor working in this repository must read and follow this file before changing anything.**

When this file and a request disagree, stop and ask the project owner. Don't guess.

## Rules

### Scope

1. **Build only what is asked, or what is listed under [Now](#now).** Nothing else, not even small extras that "might be useful".
2. **New ideas go in [Ideas](#ideas), not into the code.** Add a line there with the date and a short description, and mention it in your reply. The owner decides whether it moves into the plan.
3. **Don't build anything under [Later](#later) or [Ideas](#ideas)** until the owner moves it into [Now](#now).
4. **When the backend's behaviour is unknown, don't invent it.** Add the question to [Open questions](#open-questions) and ask. Code against real samples (`docs/fixtures/`, Postman), never against guesses.
5. **Keep changes small and on topic.** Don't refactor, rename or reformat code that the task doesn't touch.

### Public API and compatibility

6. **The public API stays small.** Don't add, rename or remove anything `public` without the owner's approval. Everything not in `Sources/PaymentSDK/Public/` is `internal`.
7. **Don't break host apps.** A breaking public change needs approval and a new major version.
8. **Minimum iOS 15, Swift 5.9, Swift Package Manager only.** Don't raise the minimum or add CocoaPods or Carthage support without approval.

### Dependencies

9. **No new dependencies without approval.** That includes Swift packages, binary frameworks and copied third-party code. PhoneNumberKit is the only one today.
10. **No analytics, tracking or attribution SDKs** (Adjust, Firebase and so on). Referrer values come from the host's configuration.

### Backend contract

11. **Every request follows the envelope in ARCHITECTURE.md exactly.** `Action` is a string. Every request gets a new `TransactionID`. A stored `SessionID` is never replaced with an empty one, and Initiate never sends one.
12. **Never call the live backend from tests.** Use fixtures. A wire-format change needs a real captured sample added to `Tests/PaymentSDKTests/Fixtures/` first.

### Privacy and security

13. **Never log PIN codes or full phone numbers.** Logging is off by default.
14. **Keep `PrivacyInfo.xcprivacy` true.** Any new data collected or new required-reason API used must be declared in the same change.
15. **No secrets in the repository:** keys, tokens or credentials.

### Quality

16. **All tests pass before a change is done.** New behaviour gets a test. Bug fixes get a test that would have caught the bug, when practical.
17. **Strict concurrency stays on.** No `@unchecked Sendable` or `nonisolated(unsafe)` without a comment explaining why it's safe.
18. **Check UI changes in the example app** on a simulator, not just by building.

### Docs

19. **Keep the docs true.** A change that affects them updates them in the same change:
    - [README.md](README.md): anything an integrating developer does or sees.
    - [ARCHITECTURE.md](ARCHITECTURE.md): structure, flow, decisions.
    - [CHANGELOG.md](CHANGELOG.md): core changes only, under `[Unreleased]`.
    - This file: move finished items to [Done](#done), and record new questions and ideas.
20. **The README is for integrating developers.** Internal details go in ARCHITECTURE.md.

### Releases

21. **Releases follow Semantic Versioning, and Swift Package Manager installs from git tags.** To release: tests pass, `[Unreleased]` in the changelog becomes the new version with the date, then tag it (`1.1.0`, no `v`) and push the tag. Never move or delete a published tag.

## Definition of done

A change is done when:

- [ ] It does what was asked, and nothing more.
- [ ] `xcodebuild test -scheme PaymentSDK -destination 'platform=iOS Simulator,name=<iPhone>'` passes.
- [ ] The example app builds, and UI changes were checked on a simulator.
- [ ] README, ARCHITECTURE, CHANGELOG and this file are still true.
- [ ] No new public API, dependency or data collection without approval.

## Done

- **1.0.0 (2026-10-20):** subscription flow (Initiate → phone → PIN), public API, launch modes, three shells chosen by the host app, bundled themes, on-screen error handling, Keychain device ID, privacy manifest, example app. See [CHANGELOG.md](CHANGELOG.md).

## Now

Approved and ready to build.

- *Nothing.* The next item is blocked; see below.

## Next

Approved, but blocked until the listed input exists.

### Dashboard initiate

A second backend call, made before the payment Initiate, that controls the SDK remotely.

- **What it decides:** whether the SDK opens on app launch, and which shell to show.
- **Without a dashboard URL:** the SDK shows the interstitial shell (`PaymentShell.fallback`), as it does today.
- **Code hook:** `BundledThemeProvider.forcedThemeID`, set in `PaymentPresenter.makeCoordinator`. The dashboard's answer replaces the shell passed by the host.
- **Blocked on:** the dashboard doesn't exist yet. Needed before starting:
  - [ ] Endpoint URL, method, request body, and a real response sample.
  - [ ] Field names for "open on launch" and "shell".
  - [ ] What happens without a dashboard URL: open the interstitial on launch automatically, or follow the host's `isOnLaunch`?
  - [ ] Whether the dashboard chooses only the shell (the payment `ThemeID` keeps colours and fonts) or the whole theme.
  - [ ] Whether `PaymentSDK.present(shell:)` stays public once the dashboard exists.

## Later

Planned, not approved to build yet.

- **Honour the backend's `ThemeID` again.** Today it's ignored while the shell is forced. Bundle the IDs the backend actually sends (for example `299`).
- **Resend PIN.** Show `AskCodeAgain` with its countdown on the PIN screen. The value is already decoded.
- **Remote themes.** A `ThemeProviding` implementation that downloads theme JSON, with the bundled files as fallback.

## Ideas

Not approved. Add new ideas here, with the date. Don't build them.

- 2026-10-20: Rename the module from the generic `PaymentSDK` to a branded name, to avoid clashing with another package's module in host apps. Breaking: must happen before host apps adopt the SDK, or in a major version.
- 2026-10-20: Run the tests in CI on every push.

## Open questions

Unknown backend behaviour. Handle it defensively in code, and don't build on guesses.

- What does a successful verifyPin response look like? The SDK assumes `Error` 0 means subscribed, with or without `NextAction` 31 (`FlowCoordinator.resultForVerifyPinWithoutRoute`).
- What does `NextAction` 7 mean beyond "error"? It's treated as an error that falls back to the retry screen after 3 in a row.
- Will `Scheme` and `SignupMethod` be used?
- Which package names does the backend accept? Unregistered bundle IDs get `Error` 1 on Initiate.
