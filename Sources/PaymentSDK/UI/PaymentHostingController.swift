import Combine
import SwiftUI
import UIKit

/// Full-screen container for the SDK flow. Follows the theme's status bar style.
final class PaymentHostingController: UIHostingController<PaymentRootView> {
    private var cancellable: AnyCancellable?
    private var lightStatusBar = false

    init(flow: FlowCoordinator) {
        super.init(rootView: PaymentRootView(flow: flow))
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
        lightStatusBar = flow.document.theme.screen.usesLightStatusBar
        cancellable = flow.$document
            .map(\.theme.screen.usesLightStatusBar)
            .removeDuplicates()
            .sink { [weak self] light in
                self?.lightStatusBar = light
                self?.setNeedsStatusBarAppearanceUpdate()
            }
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        lightStatusBar ? .lightContent : .darkContent
    }
}
