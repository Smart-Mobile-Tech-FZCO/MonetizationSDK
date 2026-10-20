import Foundation

/// The outcome of one SDK presentation, delivered to the host app's `onResult` callback.
public enum PaymentResult: Equatable {
    case subscribed
    case alreadySubscribed
    /// The user closed the flow at any step.
    case cancelled
    /// Only for unrecoverable configuration problems. Network and backend errors stay in the SDK's UI.
    case failed(PaymentSDKError)
}

public enum PaymentSDKError: Error, Equatable {
    /// `present` or the SwiftUI modifier was used before `PaymentSDK.configure(_:onResult:)`.
    case notConfigured
    /// No view controller was available to present from.
    case noPresentingViewController
}
