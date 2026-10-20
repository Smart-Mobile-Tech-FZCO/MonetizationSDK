import SwiftUI
import WebKit

/// Top-level SDK view: switches on the coordinator's screen and injects theme and language.
struct PaymentRootView: View {
    @ObservedObject var flow: FlowCoordinator
    @State private var fontGeneration = 0

    var body: some View {
        let theme = flow.document.theme
        ZStack {
            switch flow.screen {
            case .loading, .finished:
                LoadingView()
            case .intro:
                IntroPagesView(flow: flow)
            case .phone:
                if let content = flow.phoneContent {
                    PhoneScreen(flow: flow, content: content)
                }
            case .pin:
                if let content = flow.pinContent {
                    PinScreen(flow: flow, content: content)
                }
            case .retry:
                RetryView(flow: flow)
            }
        }
        .id(fontGeneration)
        .environment(\.paymentTheme, theme)
        .environment(\.paymentLanguage, flow.language)
        .environment(\.layoutDirection, flow.isRightToLeft ? .rightToLeft : .leftToRight)
        .preferredColorScheme(theme.screen.usesLightStatusBar ? .dark : .light)
        .task(id: flow.document.sourceName) {
            guard let family = theme.fontFamily, !ThemeFont.isAvailable(family) else { return }
            await ThemeFont.loadIfNeeded(family: family, from: theme.screen.fontUrl)
            if ThemeFont.isAvailable(family) { fontGeneration += 1 }
        }
    }
}

struct LoadingView: View {
    @Environment(\.paymentTheme) private var theme
    @Environment(\.paymentLanguage) private var language

    var body: some View {
        ZStack {
            ThemeBackground(fill: theme.screen.background)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: theme.button.background.color ?? "#0A84FF")))
                .scaleEffect(1.4)
                .accessibilityLabel(Text(L10n.text(.loading, language)))
        }
    }
}

/// Full-screen error after a failed Initiate or an invalid session.
struct RetryView: View {
    @ObservedObject var flow: FlowCoordinator

    @Environment(\.paymentTheme) private var theme
    @Environment(\.paymentLanguage) private var language

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ThemeBackground(fill: theme.screen.background)
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(hex: theme.button.background.color ?? "#0A84FF"))
                    .accessibilityHidden(true)
                Text(HTMLDisclaimer.attributedString(from: flow.retryMessage ?? L10n.text(.genericError, language),
                                                     baseSize: 17, baseWeight: .medium, fontFamily: theme.fontFamily))
                    .foregroundColor(Color(hex: theme.header.titleColor))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                PrimaryButton(title: L10n.text(.tryAgain, language), isLoading: flow.isSubmitting) {
                    Task { await flow.retry() }
                }
            }
            .padding(.horizontal, theme.screen.horizontalPadding)
            .padding(.bottom, 24)
            .frame(maxWidth: theme.screen.contentMaxWidth)
            .frame(maxWidth: .infinity)

            CloseButton(color: Color(hex: theme.header.closeColor), action: flow.close)
                .padding(.top, 8)
                .padding(.horizontal, 16)
        }
    }
}

/// Terms, Privacy or a link from a disclaimer, shown in a sheet.
struct HTMLSheet: View {
    let content: SheetContent

    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.paymentLanguage) private var language
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            ZStack {
                WebContentView(html: content.html, url: content.url, isLoading: $isLoading)
                if isLoading { ProgressView() }
            }
            .navigationTitle(content.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text(.close, language)) { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct WebContentView: UIViewRepresentable {
    var html: String?
    var url: URL?
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        if let html {
            let document = """
            <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
            <style>body{font-family:-apple-system,Helvetica,Arial,sans-serif;padding:12px;font-size:15px;line-height:1.4;\
            color:#111;background:#fff}img{max-width:100%;height:auto}
            @media (prefers-color-scheme: dark){body{color:#eee;background:#000}}</style></head><body>\(html)</body></html>
            """
            webView.loadHTMLString(document, baseURL: nil)
        } else if let url {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let isLoading: Binding<Bool>
        init(isLoading: Binding<Bool>) { self.isLoading = isLoading }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { isLoading.wrappedValue = false }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { isLoading.wrappedValue = false }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
        }
    }
}
