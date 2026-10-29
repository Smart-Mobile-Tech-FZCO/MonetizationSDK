import Foundation

/// The outcome of one SDK presentation, delivered to the host app's `onResult` callback.
public enum MonetizationResult: Equatable {
    case subscribed
    case alreadySubscribed
    /// The user closed the flow at any step.
    case cancelled
    /// Only for unrecoverable configuration problems. Network and backend errors stay in the SDK's UI.
    case failed(MonetizationError)
}

public enum MonetizationError: Error, Equatable {
    /// `present` or the SwiftUI modifier was used before `MonetizationSDK.configure(_:onResult:)`.
    case notConfigured
    /// No view controller was available to present from.
    case noPresentingViewController
}
