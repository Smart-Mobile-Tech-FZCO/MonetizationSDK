import SwiftUI

extension View {
    /// Presents the SDK full-screen while `isPresented` is `true`, using the configuration from
    /// `PaymentSDK.configure(_:onResult:)`. The binding is reset when the flow ends.
    /// `onResult` receives the outcome of presentations started by this modifier
    /// (instead of the handler passed to `configure`).
    public func paymentSDK(isPresented: Binding<Bool>,
                           onResult: @escaping (PaymentResult) -> Void) -> some View {
        modifier(PaymentSDKPresentationModifier(isPresented: isPresented, onResult: onResult))
    }
}

private struct PaymentSDKPresentationModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onResult: (PaymentResult) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear { presentIfNeeded() }
            .onChange(of: isPresented) { _ in presentIfNeeded() }
    }

    private func presentIfNeeded() {
        guard isPresented else { return }
        let binding = $isPresented
        let handler = onResult
        // Defer so the triggering view update finishes before UIKit presents.
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                let presented = PaymentPresenter.shared.present(from: nil) { result in
                    binding.wrappedValue = false
                    handler(result)
                }
                // Already on screen: presenting again is a no-op, so release the binding.
                if !presented, PaymentPresenter.shared.isPresenting {
                    binding.wrappedValue = false
                }
            }
        }
    }
}
