import SwiftUI

/// What a sheet shows: inline HTML (Terms, Privacy) or a URL tapped in a disclaimer.
struct SheetContent: Identifiable {
    let id = UUID()
    let title: String
    var html: String?
    var url: URL?
}

/// Shared layout for the phone and PIN screens: background, header, theme blocks,
/// disclaimers, the field, the button, legal links, inline errors and the close button.
struct FormScreen<Field: View>: View {
    let headerPicURL: URL?
    let serviceName: String?
    let topHTML: [String]
    let middleHTML: String?
    let footerHTML: String?
    let legalLinks: [LegalLink]
    let buttonTitle: String
    let isSubmitting: Bool
    let secondaryLinkTitle: String?
    let countryISO: String?
    let inlineError: String?
    let onSubmit: () -> Void
    let onSecondaryLink: () -> Void
    let onDismissError: () -> Void
    let onClose: () -> Void
    @ViewBuilder let field: () -> Field

    @Environment(\.paymentTheme) private var theme
    @Environment(\.paymentLanguage) private var language
    @State private var sheet: SheetContent?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                ThemeBackground(fill: theme.screen.background)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        FormHeader(headerPicURL: headerPicURL, serviceName: serviceName,
                                   topInset: theme.header.showsBanner ? geo.safeAreaInsets.top : 0)
                        content
                            .padding(.top, theme.spacing.top)
                            .padding(.horizontal, theme.screen.horizontalPadding)
                            .padding(.bottom, max(geo.safeAreaInsets.bottom, 16) + 16)
                            .frame(maxWidth: theme.screen.contentMaxWidth)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, theme.header.showsBanner ? 0 : 44)
                }
                .ignoresSafeArea(edges: theme.header.showsBanner ? .top : [])

                HStack {
                    Spacer()
                    CloseButton(color: Color(hex: theme.header.closeColor), action: onClose)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .overlay(alignment: .bottom) {
                if let inlineError {
                    InlineErrorBanner(message: inlineError, onTap: onDismissError)
                        .padding(.horizontal, theme.screen.horizontalPadding)
                        .padding(.bottom, 24)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: inlineError)
        }
        .sheet(item: $sheet) { content in
            HTMLSheet(content: content)
        }
    }

    private var content: some View {
        VStack(spacing: theme.spacing.componentGap) {
            ThemeBlocksView(blocks: blocks(.beforeForm), onOpen: { sheet = $0 })
            formBody
                .modifier(FormCardModifier(card: theme.formCard))
            ThemeBlocksView(blocks: blocks(.afterForm), onOpen: { sheet = $0 })
        }
    }

    private var formBody: some View {
        VStack(spacing: theme.spacing.componentGap) {
            ForEach(Array(topHTML.enumerated()), id: \.offset) { _, html in
                disclaimer(html)
            }
            Spacer().frame(height: max(0, theme.spacing.afterLogo - theme.spacing.componentGap))

            field()
                .padding(.top, theme.field.marginTop)

            if let middleHTML { disclaimer(middleHTML) }
            ThemeBlocksView(blocks: blocks(.afterMiddleDisclaimer), onOpen: { sheet = $0 })
            Spacer().frame(height: max(0, theme.spacing.afterField - theme.spacing.componentGap))

            PrimaryButton(title: buttonTitle, isLoading: isSubmitting, action: onSubmit)

            if let secondaryLinkTitle {
                Button(action: onSecondaryLink) {
                    Text(secondaryLinkTitle)
                        .font(theme.font(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: theme.text.legal.color))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }
            Spacer().frame(height: max(0, theme.spacing.afterButton - theme.spacing.componentGap))

            if let footerHTML { disclaimer(footerHTML) }
            if !legalLinks.isEmpty { legalRow }
        }
    }

    private func disclaimer(_ html: String) -> some View {
        HTMLText(html: html, style: theme.text.disclaimer) { url in
            sheet = SheetContent(title: url.host ?? "", url: url)
        }
    }

    private var legalRow: some View {
        let style = theme.text.legal
        return HStack(spacing: 16) {
            ForEach(legalLinks) { link in
                Button {
                    sheet = SheetContent(title: link.title, html: link.html)
                } label: {
                    Text(link.title)
                        .font(theme.font(size: style.fontSize, weight: .medium))
                        .underline()
                        .foregroundColor(Color(hex: style.color))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: ThemeAlignment.frame(style.alignment))
    }

    private func blocks(_ placement: ThemeBlock.Placement) -> [ThemeBlock] {
        theme.blocks.filter { $0.placement == placement && ($0.condition?.matches(countryISO: countryISO) ?? true) }
    }
}

/// Wraps the form in the theme's `formCard`, when it has one.
private struct FormCardModifier: ViewModifier {
    let card: ThemeTokens.FormCard?

    func body(content: Content) -> some View {
        if let card {
            let shape = RoundedRectangle(cornerRadius: card.cornerRadius ?? 16)
            content
                .padding(card.padding ?? 20)
                .background(shape.fill(Color(hex: card.background)))
                .overlay(shape.stroke(Color(optionalHex: card.borderColor) ?? .clear, lineWidth: card.borderWidth ?? 0))
                .shadow(color: Color(optionalHex: card.shadowColor) ?? .clear,
                        radius: (card.shadowRadius ?? 0) / 2, y: (card.shadowY ?? 0) / 2)
                .padding(.top, card.marginTop ?? 0)
        } else {
            content
        }
    }
}

/// Banner (theme `header.style` image/color) or an inline logo. The service logo comes
/// from the API (`NextAction.Title.HeaderPic`); `header.logoUrl` is the theme's own artwork.
struct FormHeader: View {
    let headerPicURL: URL?
    let serviceName: String?
    let topInset: CGFloat

    @Environment(\.paymentTheme) private var theme

    var body: some View {
        if theme.header.showsBanner {
            banner
        } else {
            VStack(spacing: theme.spacing.componentGap) {
                serviceLogo
                themeLogo
            }
        }
    }

    private var banner: some View {
        let width = UIScreen.main.bounds.width
        let ratio = max(theme.header.aspectRatio ?? 1.5, 0.6)
        return VStack(spacing: 16) {
            serviceLogo
            themeLogo
        }
        .padding(.top, topInset + 52)
        .padding(.bottom, 20)
        .frame(width: width)
        .frame(minHeight: width / ratio, alignment: .top)
        .background(
            ZStack {
                Color(hex: theme.header.backgroundColor ?? "#111111")
                if let url = URL(string: theme.header.imageUrl ?? "") {
                    RemoteImage(url: url, contentMode: .fill, showsProgress: false)
                }
            }
            .clipped()
        )
        .clipShape(BottomRoundedRectangle(radius: theme.header.bottomCornerRadius ?? 0))
    }

    @ViewBuilder
    private var serviceLogo: some View {
        if let headerPicURL {
            RemoteImage(url: headerPicURL, tint: Color(hex: theme.header.titleColor))
                .frame(maxWidth: UIScreen.main.bounds.width * 0.72, maxHeight: theme.header.logoMaxHeight)
                .frame(height: theme.header.logoMaxHeight)
                .accessibilityLabel(Text(serviceName ?? ""))
        }
    }

    @ViewBuilder
    private var themeLogo: some View {
        if let url = URL(string: theme.header.logoUrl ?? "") {
            let ratio = max(theme.header.logoAspectRatio ?? 1.74, 0.5)
            let maxWidth = min(UIScreen.main.bounds.width * 0.9, theme.screen.contentMaxWidth)
            RemoteImage(url: url, showsProgress: false)
                .frame(width: maxWidth, height: maxWidth / ratio)
                .accessibilityHidden(true)
        }
    }
}
