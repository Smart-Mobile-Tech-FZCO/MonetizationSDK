import UIKit

/// Owns the configuration and the single active presentation.
@MainActor
final class PaymentPresenter {
    static let shared = PaymentPresenter()

    private(set) var configuration: PaymentSDKConfiguration?
    private var defaultResultHandler: ((PaymentResult) -> Void)?
    private var activeController: UIViewController?
    private var launchObservers: [NSObjectProtocol] = []
    private var didPresentOnLaunch = false

    /// Shared so the device ID is resolved (and persisted) once per process.
    private lazy var deviceIdentity = DeviceIdentity()

    var isPresenting: Bool { activeController != nil }

    func configure(_ configuration: PaymentSDKConfiguration, onResult: @escaping (PaymentResult) -> Void) {
        self.configuration = configuration
        defaultResultHandler = onResult
        if configuration.isOnLaunch && !didPresentOnLaunch {
            presentWhenAppIsActive()
        }
    }

    /// Presents a fresh session. `onResult` overrides the handler passed to `configure`.
    /// Returns `false` if nothing was presented (already presented, or failed and reported).
    @discardableResult
    func present(from viewController: UIViewController?, shell: PaymentShell? = nil,
                 onResult: ((PaymentResult) -> Void)? = nil) -> Bool {
        guard !isPresenting else { return false }
        let handler = onResult ?? defaultResultHandler
        guard let configuration else {
            handler?(.failed(.notConfigured))
            return false
        }
        guard let presenter = viewController ?? Self.topMostViewController() else {
            handler?(.failed(.noPresentingViewController))
            return false
        }

        let flow = makeCoordinator(configuration, shell: shell ?? .fallback)
        let controller = PaymentHostingController(flow: flow)
        flow.onFinish = { [weak self, weak controller] result in
            guard let self else { return }
            let finish = {
                self.activeController = nil
                handler?(result)
            }
            if let controller, controller.presentingViewController != nil {
                controller.dismiss(animated: true, completion: finish)
            } else {
                finish()
            }
        }
        activeController = controller
        presenter.present(controller, animated: true)
        Task { await flow.start() }
        return true
    }

    private func makeCoordinator(_ configuration: PaymentSDKConfiguration, shell: PaymentShell) -> FlowCoordinator {
        let logger = SDKLogger(isEnabled: configuration.isLoggingEnabled)
        let deviceInfo = DeviceInfoProvider(identity: deviceIdentity, packageNameOverride: configuration.packageName)
        let language = deviceInfo.languageCode
        let api = PaymentAPI(client: URLSessionAPIClient(logger: logger),
                             initiateURL: configuration.initiateURL,
                             apiURL: configuration.apiURL)
        let themes = BundledThemeProvider(forcedThemeID: shell.themeID)
        return FlowCoordinator(
            api: api,
            factory: RequestFactory(deviceInfo: deviceInfo.deviceInfo(), referrer: ReferrerPayload(configuration.referrer)),
            themes: themes,
            validator: PhoneNumberValidator.shared,
            language: language,
            initialDocument: themes.resolve(themeID: nil),
            defaultDialCode: Self.defaultDialCode(referrerCountry: configuration.referrer.country)
        )
    }

    /// Dial code for the picker when the backend does not lock one: referrer country, then device region.
    static func defaultDialCode(referrerCountry: String?) -> String {
        let region: String?
        if #available(iOS 16, *) {
            region = Locale.current.region?.identifier
        } else {
            region = Locale.current.regionCode
        }
        let country = CountryCatalog.country(forISO: referrerCountry) ?? CountryCatalog.country(forISO: region)
        return (country ?? CountryCatalog.country(forDial: "+1")).dial.filter(\.isNumber)
    }

    // MARK: - Launch mode

    private func presentWhenAppIsActive() {
        if tryPresentOnLaunch() { return }
        guard launchObservers.isEmpty else { return }
        let center = NotificationCenter.default
        for name in [UIScene.didActivateNotification, UIWindow.didBecomeKeyNotification,
                     UIApplication.didBecomeActiveNotification] {
            launchObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { _ = PaymentPresenter.shared.tryPresentOnLaunch() }
            })
        }
    }

    /// Presents once a foreground-active scene has a key window whose top controller is on screen.
    private func tryPresentOnLaunch(attempt: Int = 0) -> Bool {
        guard !didPresentOnLaunch else { return true }
        guard let top = Self.topMostViewController(), top.view.window != nil else {
            if attempt < 20, Self.activeKeyWindow() != nil {
                // Window exists but its root controller is not in the hierarchy yet.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    _ = self?.tryPresentOnLaunch(attempt: attempt + 1)
                }
            }
            return false
        }
        didPresentOnLaunch = true
        launchObservers.forEach(NotificationCenter.default.removeObserver)
        launchObservers.removeAll()
        // Let the current layout/transition finish first.
        DispatchQueue.main.async { [weak self] in
            self?.present(from: nil)
        }
        return true
    }

    // MARK: - Top-most view controller

    static func activeKeyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        return scenes.lazy.compactMap { $0.windows.first(where: \.isKeyWindow) }.first
    }

    static func topMostViewController() -> UIViewController? {
        var top = activeKeyWindow()?.rootViewController
        while true {
            if let presented = top?.presentedViewController, !presented.isBeingDismissed {
                top = presented
            } else if let navigation = top as? UINavigationController, let visible = navigation.visibleViewController {
                top = visible
            } else if let tabs = top as? UITabBarController, let selected = tabs.selectedViewController {
                top = selected
            } else {
                return top
            }
        }
    }
}
