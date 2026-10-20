/// The screens wrapped around the phone and PIN screens.
/// The dashboard will choose this once it exists; until then the host can pick one per presentation.
public enum PaymentShell: String, CaseIterable, Sendable {
    /// Straight to the phone screen.
    case single
    /// Several intro pages, then the phone screen.
    case onboarding
    /// One full-screen page with a delayed close button, then the phone screen.
    case interstitial

    /// Used when no shell is passed, because there is no dashboard to choose one yet.
    public static let fallback: PaymentShell = .interstitial

    /// Bundled theme file for this shell.
    var themeID: String { "shell-\(rawValue)" }
}
