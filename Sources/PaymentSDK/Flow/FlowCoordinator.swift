import Combine
import Foundation

/// Drives one SDK presentation: Initiate → (intro pages) → phone → PIN → result.
/// All state lives on the main actor; network calls are awaited, never shared across threads.
@MainActor
final class FlowCoordinator: ObservableObject {

    enum Screen: Equatable {
        case loading
        case intro
        case phone
        case pin
        /// Full-screen error with "Try again" (fresh Initiate) and close.
        case retry
        case finished
    }

    enum Step: Hashable {
        case sendPin
        case verifyPin
    }

    /// Same step failing with Action 7 this many times in a row falls back to the retry screen.
    static let maxConsecutiveStopErrors = 3

    @Published private(set) var screen: Screen = .loading
    @Published private(set) var document: PresentationDocument
    @Published private(set) var introPageIndex = 0
    @Published private(set) var phoneContent: PhoneScreenContent?
    @Published private(set) var pinContent: PinScreenContent?
    @Published private(set) var retryMessage: String?
    @Published private(set) var inlineError: String?
    @Published private(set) var isSubmitting = false

    /// Local (national) digits typed by the user. Kept when going back from the PIN screen.
    @Published var phoneNumber = ""
    /// Dial code digits for the phone field when the backend does not lock one.
    @Published var selectedDialCode: String
    @Published var pin = ""

    let language: String
    var isRightToLeft: Bool { DeviceInfoProvider.isRightToLeft(language) }
    var countryISO: String? { context.countryISO }

    /// Called exactly once with the outcome.
    var onFinish: ((PaymentResult) -> Void)?

    private(set) var sessionID: String?
    private(set) var context = SessionContext()
    private var stopErrorStreak: [Step: Int] = [:]
    private var screenAfterIntro: Screen = .phone
    private var lastPhn: String?
    private var errorDismissTask: Task<Void, Never>?

    private let api: PaymentAPI
    private let factory: RequestFactory
    private let themes: ThemeProviding
    private let validator: PhoneValidating
    private let errorDismissDelay: TimeInterval?

    init(api: PaymentAPI,
         factory: RequestFactory,
         themes: ThemeProviding,
         validator: PhoneValidating,
         language: String,
         initialDocument: PresentationDocument,
         defaultDialCode: String,
         errorDismissDelay: TimeInterval? = 4) {
        self.api = api
        self.factory = factory
        self.themes = themes
        self.validator = validator
        self.language = language
        self.document = initialDocument
        self.selectedDialCode = defaultDialCode
        self.errorDismissDelay = errorDismissDelay
    }

    var dialCodeForPhone: String { phoneContent?.lockedDialCode ?? selectedDialCode }

    // MARK: - Initiate

    /// Starts a fresh session: no SessionID, new TransactionID.
    func start() async {
        guard screen != .finished, !isSubmitting else { return }
        sessionID = nil
        context = SessionContext()
        stopErrorStreak = [:]
        phoneContent = nil
        pinContent = nil
        pin = ""
        retryMessage = nil
        clearInlineError()
        screen = .loading

        isSubmitting = true
        defer { isSubmitting = false }

        let response: APIResponse
        do {
            response = try await api.send(factory.initiate())
        } catch {
            guard screen != .finished else { return }
            await showRetry(message: nil, themeID: nil)
            return
        }
        guard screen != .finished else { return }
        await handleInitiate(response)
    }

    /// "Try again" on the retry screen.
    func retry() async {
        guard screen == .retry else { return }
        await start()
    }

    private func handleInitiate(_ response: APIResponse) async {
        guard response.isSuccess else {
            await showRetry(message: response.message, themeID: response.resolvedThemeID)
            return
        }
        storeSession(response.sessionID)
        context.absorb(response)
        document = await themes.document(forThemeID: response.resolvedThemeID)
        introPageIndex = 0

        switch response.nextAction?.action {
        case NextActionCode.phone:
            showPhone(from: response, afterIntro: true)
        case NextActionCode.pin:
            showPin(from: response, afterIntro: true)
        case NextActionCode.openContent:
            finish(response.isAlreadySubscribed ? .alreadySubscribed : .subscribed)
        default:
            await showRetry(message: response.message, themeID: nil)
        }
    }

    // MARK: - Intro pages

    func advanceIntro() {
        guard screen == .intro else { return }
        if document.template == .interstitial || introPageIndex + 1 >= document.pages.count {
            screen = screenAfterIntro
        } else {
            introPageIndex += 1
        }
    }

    func retreatIntro() {
        guard screen == .intro, introPageIndex > 0 else { return }
        introPageIndex -= 1
    }

    // MARK: - sendPin

    func submitPhone() async {
        guard screen == .phone, !isSubmitting else { return }
        switch validator.validate(local: phoneNumber, dialCode: dialCodeForPhone) {
        case .invalid(let key):
            showInlineError(phoneContent?.validationMessage ?? L10n.text(key, language))
        case .valid(let phn):
            lastPhn = phn
            await perform(.sendPin, factory.sendPin(sessionID: sessionID ?? "", phn: phn))
        }
    }

    // MARK: - verifyPin

    func submitPin() async {
        guard screen == .pin, !isSubmitting else { return }
        let code = pin.westernDigits.trimmingCharacters(in: .whitespacesAndNewlines)
        let required = pinContent?.pinLength ?? 1
        guard !code.isEmpty, code.count >= required else {
            showInlineError(pinContent?.validationMessage ?? L10n.text(.enterPin, language))
            return
        }
        await perform(.verifyPin, factory.verifyPin(sessionID: sessionID ?? "", pinCode: code))
    }

    /// "Wrong number?" on the PIN screen: back to the phone screen, same session, number kept.
    func editPhoneNumber() {
        guard screen == .pin, !isSubmitting else { return }
        pin = ""
        clearInlineError()
        screen = .phone
    }

    // MARK: - Close

    func close() {
        finish(.cancelled)
    }

    func dismissInlineError() {
        clearInlineError()
    }

    // MARK: - Step handling

    private func perform(_ step: Step, _ envelope: RequestEnvelope) async {
        let screenAtStart = screen
        clearInlineError()
        isSubmitting = true
        defer { isSubmitting = false }

        let response: APIResponse
        do {
            response = try await api.send(envelope)
        } catch {
            // Network error, non-2xx or undecodable body: inline, session kept.
            guard screen == screenAtStart else { return }
            if step == .verifyPin { pin = "" }
            showInlineError(L10n.text(.networkError, language))
            return
        }
        guard screen == screenAtStart else { return } // closed or navigated away meanwhile

        storeSession(response.sessionID)
        if response.isSuccess {
            await handleStepSuccess(response, step: step)
        } else {
            await handleStepFailure(response, step: step)
        }
    }

    private func handleStepSuccess(_ response: APIResponse, step: Step) async {
        stopErrorStreak[step] = 0
        context.absorb(response)
        switch response.nextAction?.action {
        case NextActionCode.pin:
            showPin(from: response, afterIntro: false)
        case NextActionCode.phone:
            showPhone(from: response, afterIntro: false)
        case NextActionCode.openContent:
            finish(response.isAlreadySubscribed ? .alreadySubscribed : .subscribed)
        default:
            if step == .verifyPin {
                finish(Self.resultForVerifyPinWithoutRoute(response))
            } else {
                showInlineError(response.message ?? L10n.text(.genericError, language))
            }
        }
    }

    /// verifyPin succeeded (`Error` 0 or 3) but `NextAction` is missing or unknown.
    /// No real success sample exists yet; change the assumption here.
    static func resultForVerifyPinWithoutRoute(_ response: APIResponse) -> PaymentResult {
        response.isAlreadySubscribed ? .alreadySubscribed : .subscribed
    }

    private func handleStepFailure(_ response: APIResponse, step: Step) async {
        if step == .verifyPin { pin = "" }
        let message = response.message ?? L10n.text(.genericError, language)

        if response.nextAction?.action == NextActionCode.stop {
            let streak = (stopErrorStreak[step] ?? 0) + 1
            stopErrorStreak[step] = streak
            let sessionInvalid = response.sessionID.map { $0.nonEmptyTrimmed == nil } ?? false
            if sessionInvalid || streak >= Self.maxConsecutiveStopErrors {
                await showRetry(message: message, themeID: nil)
                return
            }
        } else {
            stopErrorStreak[step] = 0
        }
        showInlineError(message)
    }

    // MARK: - Transitions

    private func showPhone(from response: APIResponse, afterIntro: Bool) {
        let content = ScreenContentMapper.phone(from: response, context: context, language: language)
        phoneContent = content
        if let locked = content.lockedDialCode { selectedDialCode = locked }
        route(to: .phone, afterIntro: afterIntro)
    }

    private func showPin(from response: APIResponse, afterIntro: Bool) {
        pinContent = ScreenContentMapper.pin(from: response, context: context, language: language, phn: lastPhn)
        pin = ""
        route(to: .pin, afterIntro: afterIntro)
    }

    private func route(to target: Screen, afterIntro: Bool) {
        clearInlineError()
        if afterIntro && document.hasIntro {
            screenAfterIntro = target
            screen = .intro
        } else {
            screen = target
        }
    }

    private func showRetry(message: String?, themeID: String?) async {
        if let themeID {
            document = await themes.document(forThemeID: themeID)
        }
        guard screen != .finished else { return }
        sessionID = nil
        clearInlineError()
        retryMessage = message ?? L10n.text(.genericError, language)
        screen = .retry
    }

    private func finish(_ result: PaymentResult) {
        guard screen != .finished else { return }
        clearInlineError()
        screen = .finished
        let callback = onFinish
        onFinish = nil
        callback?(result)
    }

    /// Never replace a stored SessionID with an empty one; error responses send `""`.
    private func storeSession(_ value: String?) {
        guard let value = value?.nonEmptyTrimmed else { return }
        sessionID = value
    }

    private func showInlineError(_ message: String) {
        errorDismissTask?.cancel()
        inlineError = message
        guard let delay = errorDismissDelay else { return }
        errorDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self, self.inlineError == message else { return }
            self.inlineError = nil
        }
    }

    private func clearInlineError() {
        errorDismissTask?.cancel()
        errorDismissTask = nil
        inlineError = nil
    }
}
