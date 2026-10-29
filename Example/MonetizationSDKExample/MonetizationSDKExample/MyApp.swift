import Combine
import MonetizationSDK
import SwiftUI

@main
struct MonetizationSDKExampleApp: App {
    @StateObject private var results = ResultLog.shared

    init() {
        // Read before configuring: the toggle takes effect on the next launch.
        // Defaults to on: with no dashboard yet, the SDK opens on launch with the interstitial shell.
        UserDefaults.standard.register(defaults: [ExampleSettings.isOnLaunchKey: true])
        let isOnLaunch = UserDefaults.standard.bool(forKey: ExampleSettings.isOnLaunchKey)
        MonetizationSDK.configure(
            MonetizationConfiguration(isOnLaunch: isOnLaunch,
                                    // The backend only accepts registered package names.
                                    packageName: "com.aitrend.nativesdk",
                                    isLoggingEnabled: true)
        ) { result in
            ResultLog.shared.record(result)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(results)
        }
    }
}

enum ExampleSettings {
    static let isOnLaunchKey = "example.isOnLaunch"
}

/// Last result reported by the SDK, from any entry point.
@MainActor
final class ResultLog: ObservableObject {
    static let shared = ResultLog()

    @Published private(set) var last: MonetizationResult?
    @Published private(set) var receivedAt: Date?

    func record(_ result: MonetizationResult) {
        last = result
        receivedAt = Date()
    }
}

extension MonetizationResult {
    var displayText: String {
        switch self {
        case .subscribed: return "Subscribed"
        case .alreadySubscribed: return "Already subscribed"
        case .cancelled: return "Cancelled"
        case .failed(let error): return "Failed: \(error)"
        }
    }
}
