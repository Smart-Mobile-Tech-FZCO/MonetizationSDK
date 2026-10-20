import PaymentSDK
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var results: ResultLog
    @AppStorage(ExampleSettings.isOnLaunchKey) private var isOnLaunch = true
    @State private var showSDK = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Present on launch", isOn: $isOnLaunch)
                } footer: {
                    Text("Sets isOnLaunch. Takes effect the next time the app launches.")
                }

                Section {
                    Button("Present SDK (UIKit API)") {
                        PaymentSDK.present()
                    }
                    Button("Present SDK (SwiftUI modifier)") {
                        showSDK = true
                    }
                }

                Section {
                    Button("Interstitial") { PaymentSDK.present(shell: .interstitial) }
                    Button("Onboarding") { PaymentSDK.present(shell: .onboarding) }
                    Button("Single (phone screen only)") { PaymentSDK.present(shell: .single) }
                } header: {
                    Text("Shells")
                } footer: {
                    Text("Until the dashboard exists, each button picks the shell. The buttons above use the interstitial.")
                }

                Section("Last result") {
                    HStack {
                        Text(results.last?.displayText ?? "None yet")
                            .accessibilityIdentifier("lastResult")
                        Spacer()
                        if let date = results.receivedAt {
                            Text(date, style: .time).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("PaymentSDK Example")
        }
        .navigationViewStyle(.stack)
        .paymentSDK(isPresented: $showSDK) { result in
            results.record(result)
        }
    }
}
