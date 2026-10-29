import UIKit

/// Entry point for host apps.
///
/// ```swift
/// MonetizationSDK.configure(MonetizationConfiguration(isOnLaunch: false)) { result in
///     print(result)
/// }
/// MonetizationSDK.present()
/// ```
@MainActor
public enum MonetizationSDK {

    /// Stores the configuration and the result handler. Call once, e.g. from
    /// `application(_:didFinishLaunchingWithOptions:)` or your SwiftUI `App.init`.
    /// With `isOnLaunch: true`, the SDK presents itself once, full-screen, as soon as
    /// a foreground-active window scene with a key window exists.
    public static func configure(_ config: MonetizationConfiguration,
                                 onResult: @escaping (MonetizationResult) -> Void) {
        MonetizationPresenter.shared.configure(config, onResult: onResult)
    }

    /// Presents the flow full-screen, starting a fresh session.
    /// - Parameters:
    ///   - viewController: The presenter. `nil` uses the top-most view controller.
    ///   - shell: The screens around the phone and PIN screens. `nil` uses `MonetizationShell.fallback`.
    /// Presenting while the SDK is already on screen does nothing.
    public static func present(from viewController: UIViewController? = nil, shell: MonetizationShell? = nil) {
        MonetizationPresenter.shared.present(from: viewController, shell: shell)
    }
}
