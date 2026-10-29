import SwiftUI

/// Onboarding pages or the single interstitial page shown before the phone screen.
struct IntroPagesView: View {
    @ObservedObject var flow: FlowCoordinator

    @Environment(\.paymentTheme) private var theme
    @Environment(\.paymentLanguage) private var language
    @State private var closeRemaining = 0
    @State private var closeReady = false

    private var document: PresentationDocument { flow.document }
    private var isInterstitial: Bool { document.template == .interstitial }
    private var page: PresentationPage? {
        let index = isInterstitial ? 0 : flow.introPageIndex
        return document.pages.indices.contains(index) ? document.pages[index] : nil
    }
    private var copyAlignment: String? { theme.text.disclaimer.alignment }

    var body: some View {
        Group {
            if isInterstitial { interstitial } else { onboarding }
        }
    }

    // MARK: Interstitial

    private var interstitial: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                ThemeBackground(fill: theme.screen.background)
                if let url = URL(string: page?.imageUrl ?? "") {
                    // The image fills the screen without changing the layout size, so the button stays on screen.
                    Color.clear
                        .overlay(RemoteImage(url: url, contentMode: .fill, showsProgress: false))
                        .clipped()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.2), .black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                if let page {
                    VStack(spacing: theme.spacing.componentGap) {
                        Spacer(minLength: 0)
                        copy(page, includeSubtitle: false)
                        PrimaryButton(title: page.buttonTitle(language), action: flow.advanceIntro)
                    }
                    .padding(.horizontal, theme.screen.horizontalPadding)
                    .padding(.bottom, 16)
                    .frame(maxWidth: theme.screen.contentMaxWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                closeControl
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
            }
        }
        .task(id: document.closeDelay) { await runCloseCountdown() }
    }

    @ViewBuilder
    private var closeControl: some View {
        if closeReady || document.closeDelay == 0 {
            CloseButton(color: Color(hex: theme.header.closeColor), background: .black.opacity(0.45), action: flow.close)
        } else {
            Text("\(closeRemaining > 0 ? closeRemaining : document.closeDelay)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: theme.header.closeColor))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.black.opacity(0.45)))
                .accessibilityHidden(true)
        }
    }

    private func runCloseCountdown() async {
        let delay = document.closeDelay
        guard delay > 0 else {
            closeReady = true
            return
        }
        closeReady = false
        closeRemaining = delay
        for _ in 0..<delay {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            closeRemaining = max(0, closeRemaining - 1)
        }
        closeReady = true
    }

    // MARK: Onboarding

    private var onboarding: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                ThemeBackground(fill: theme.screen.background)
                if let page {
                    VStack(spacing: 0) {
                        hero(page.imageUrl, width: geo.size.width, height: geo.size.height * 0.46)
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: ThemeAlignment.horizontal(copyAlignment), spacing: theme.spacing.componentGap) {
                                copy(page, includeSubtitle: true)
                                points(page)
                                gallery(page.images, width: geo.size.width - theme.screen.horizontalPadding * 2)
                            }
                            .padding(.horizontal, theme.screen.horizontalPadding)
                            .padding(.vertical, 20)
                            .frame(maxWidth: theme.screen.contentMaxWidth)
                            .frame(maxWidth: .infinity)
                        }
                        pageDots.padding(.bottom, 10)
                        PrimaryButton(title: page.buttonTitle(language), action: flow.advanceIntro)
                            .padding(.horizontal, theme.screen.horizontalPadding)
                            .padding(.bottom, 12)
                            .frame(maxWidth: theme.screen.contentMaxWidth)
                    }
                    .id(flow.introPageIndex)
                    .transition(.opacity)
                }
                CloseButton(color: Color(hex: theme.header.closeColor), background: .black.opacity(0.35), action: flow.close)
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: flow.introPageIndex)
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                let forward = flow.isRightToLeft ? value.translation.width > 60 : value.translation.width < -60
                let backward = flow.isRightToLeft ? value.translation.width < -60 : value.translation.width > 60
                if forward { flow.advanceIntro() } else if backward { flow.retreatIntro() }
            }
        )
    }

    private func hero(_ raw: String?, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Color(hex: theme.screen.background.color ?? "#000000")
            if let url = URL(string: raw ?? "") {
                RemoteImage(url: url, contentMode: .fill, showsProgress: false)
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder
    private func copy(_ page: PresentationPage, includeSubtitle: Bool) -> some View {
        let align = ThemeAlignment.text(copyAlignment)
        let frame = ThemeAlignment.frame(copyAlignment)
        if let title = page.title?.resolve(language).nonEmptyTrimmed {
            Text(title)
                .font(theme.font(size: 28, weight: .bold))
                .foregroundColor(Color(hex: theme.header.titleColor))
                .multilineTextAlignment(align)
                .frame(maxWidth: .infinity, alignment: frame)
        }
        if includeSubtitle, let subtitle = page.subtitle?.resolve(language).nonEmptyTrimmed {
            Text(subtitle)
                .font(theme.font(size: 17, weight: .semibold))
                .foregroundColor(Color(hex: theme.header.titleColor).opacity(0.8))
                .multilineTextAlignment(align)
                .frame(maxWidth: .infinity, alignment: frame)
        }
        if let text = page.text?.resolve(language).nonEmptyTrimmed {
            Text(text)
                .font(theme.font(size: theme.text.disclaimer.fontSize))
                .foregroundColor(Color(hex: theme.text.disclaimer.color))
                .multilineTextAlignment(align)
                .frame(maxWidth: .infinity, alignment: frame)
        }
    }

    @ViewBuilder
    private func points(_ page: PresentationPage) -> some View {
        let items = page.points.compactMap { $0.resolve(language).nonEmptyTrimmed }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color(hex: theme.button.background.color ?? "#0A84FF"))
                            .frame(width: 7, height: 7)
                            .padding(.top, 6)
                        Text(point)
                            .font(theme.font(size: theme.text.disclaimer.fontSize, weight: .medium))
                            .foregroundColor(Color(hex: theme.header.titleColor))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func gallery(_ urls: [String], width: CGFloat) -> some View {
        let resolved = urls.compactMap(URL.init(string:))
        if !resolved.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(resolved.enumerated()), id: \.offset) { _, url in
                        RemoteImage(url: url, contentMode: .fill, showsProgress: false)
                            .frame(width: min(width * 0.42, 160), height: 110)
                            .clipped()
                            .cornerRadius(12)
                    }
                }
            }
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(document.pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == flow.introPageIndex
                          ? Color(hex: theme.button.background.color ?? "#0A84FF")
                          : Color(hex: theme.header.titleColor).opacity(0.2))
                    .frame(width: index == flow.introPageIndex ? 18 : 6, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(flow.introPageIndex + 1) / \(document.pages.count)"))
    }
}
