import SwiftUI

/// Renders theme `blocks`: link, imageCarousel, cardGrid, logoRow, faq, imageGrid.
struct ThemeBlocksView: View {
    let blocks: [ThemeBlock]
    let onOpen: (SheetContent) -> Void

    @Environment(\.paymentTheme) private var theme

    var body: some View {
        ForEach(blocks, id: \.id) { block in
            Group {
                switch block.kind {
                case .link: LinkBlock(block: block, onOpen: onOpen)
                case .imageCarousel: CarouselBlock(block: block)
                case .cardGrid: CardGridBlock(block: block)
                case .logoRow: LogoRowBlock(block: block)
                case .faq: FAQBlock(block: block)
                case .imageGrid: ImageGridBlock(block: block)
                }
            }
            .padding(.top, block.style.marginTop ?? 0)
        }
    }
}

private func imageURL(_ text: LocalizedText?, _ language: String) -> URL? {
    guard let raw = text?.resolve(language).nonEmptyTrimmed else { return nil }
    return URL(string: raw) ?? raw.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed).flatMap(URL.init(string:))
}

private struct LinkBlock: View {
    let block: ThemeBlock
    let onOpen: (SheetContent) -> Void

    @Environment(\.paymentTheme) private var theme
    @Environment(\.paymentLanguage) private var language

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(block.items.enumerated()), id: \.offset) { _, item in
                if let url = item.url.flatMap(URL.init(string:)) {
                    let title = item.text?.resolve(language) ?? url.host ?? ""
                    Button { onOpen(SheetContent(title: title, url: url)) } label: {
                        Text(title)
                            .font(theme.font(size: block.style.fontSize ?? theme.text.legal.fontSize, weight: .medium))
                            .underline()
                            .foregroundColor(Color(hex: block.style.color ?? theme.text.legal.color))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CarouselBlock: View {
    let block: ThemeBlock

    @Environment(\.paymentLanguage) private var language
    @State private var index = 0

    var body: some View {
        let urls = block.items.compactMap { imageURL($0.imageUrl, language) }
        let ratio = block.style.aspectRatio ?? 2
        let shape = RoundedRectangle(cornerRadius: block.style.cornerRadius ?? 12)
        if !urls.isEmpty {
            TabView(selection: $index) {
                ForEach(Array(urls.enumerated()), id: \.offset) { offset, url in
                    RemoteImage(url: url, contentMode: block.style.contentMode == "fill" ? .fill : .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .automatic : .never))
            .aspectRatio(ratio, contentMode: .fit)
            .clipShape(shape)
            .shadow(color: Color(optionalHex: block.style.shadowColor) ?? .clear, radius: 12, y: 6)
            .environment(\.layoutDirection, .leftToRight)
            .task(id: urls.count) {
                let interval = block.intervalSeconds ?? 0
                guard interval > 0, urls.count > 1 else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    if Task.isCancelled { return }
                    withAnimation { index = (index + 1) % urls.count }
                }
            }
        }
    }
}

private struct CardGridBlock: View {
    let block: ThemeBlock

    @Environment(\.paymentTheme) private var theme
    @Environment(\.paymentLanguage) private var language

    var body: some View {
        let style = block.style
        let gap = style.gap ?? 10
        let columns = Array(repeating: GridItem(.flexible(), spacing: gap), count: max(1, block.columns ?? 2))
        LazyVGrid(columns: columns, spacing: gap) {
            ForEach(Array(block.items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: Self.symbol(item.icon))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: style.iconColor ?? "#FFFFFF"))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(LinearGradient(colors: (style.iconBackgroundColors ?? ["#007BA7"]).map(Color.init(hex:)),
                                                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
                    Text(item.title?.resolve(language) ?? "")
                        .font(theme.font(size: style.titleFontSize ?? 13, weight: .bold))
                        .foregroundColor(Color(hex: style.titleColor ?? "#FFFFFF"))
                    Text(item.text?.resolve(language) ?? "")
                        .font(theme.font(size: style.textFontSize ?? 11))
                        .foregroundColor(Color(hex: style.textColor ?? "#FFFFFF"))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: style.cardMinHeight ?? 0, alignment: .topLeading)
                .background(LinearGradient(colors: (style.cardOverlayColors ?? ["#33000000"]).map(Color.init(hex:)),
                                           startPoint: .top, endPoint: .bottom))
                .clipShape(RoundedRectangle(cornerRadius: style.cardCornerRadius ?? 12))
            }
        }
    }

    static func symbol(_ icon: String?) -> String {
        switch icon {
        case "cloud": return "cloud.fill"
        case "devices": return "laptopcomputer.and.iphone"
        case "unlimited": return "infinity"
        case "hd": return "tv"
        default: return "star.fill"
        }
    }
}

private struct LogoRowBlock: View {
    let block: ThemeBlock

    @Environment(\.paymentTheme) private var theme
    @Environment(\.paymentLanguage) private var language

    var body: some View {
        let style = block.style
        let width = style.logoWidth ?? 60
        VStack(spacing: style.gap ?? 10) {
            ForEach(Array(block.items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: style.gap ?? 10) {
                    if let label = item.label?.resolve(language).nonEmptyTrimmed {
                        Text(label)
                            .font(theme.font(size: style.fontSize ?? 12))
                            .foregroundColor(Color(hex: style.color ?? theme.text.disclaimer.color))
                    }
                    if let url = imageURL(item.imageUrl, language) {
                        RemoteImage(url: url, showsProgress: false)
                            .frame(width: width, height: width / max(style.logoAspectRatio ?? 4, 0.1))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FAQBlock: View {
    let block: ThemeBlock

    @Environment(\.paymentTheme) private var theme
    @Environment(\.paymentLanguage) private var language
    @State private var expanded: Set<Int> = []

    var body: some View {
        let style = block.style
        VStack(spacing: 10) {
            if let title = block.title?.resolve(language).nonEmptyTrimmed {
                Text(title)
                    .font(theme.font(size: style.titleFontSize ?? 20, weight: .bold))
                    .foregroundColor(Color(hex: style.titleColor ?? theme.header.titleColor))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
            }
            ForEach(Array(block.items.enumerated()), id: \.offset) { index, item in
                let isOpen = expanded.contains(index)
                let shape = RoundedRectangle(cornerRadius: style.itemCornerRadius ?? 12)
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isOpen { expanded.remove(index) } else { expanded.insert(index) }
                        }
                    } label: {
                        HStack(alignment: .top) {
                            Text(item.question?.resolve(language) ?? "")
                                .font(theme.font(size: style.questionFontSize ?? 14, weight: .semibold))
                                .foregroundColor(Color(hex: style.questionColor ?? "#333333"))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.down")
                                .rotationEffect(.degrees(isOpen ? 180 : 0))
                                .foregroundColor(Color(hex: style.questionColor ?? "#333333"))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOpen ? [.isSelected] : [])

                    if isOpen, let answer = item.answer?.resolve(language) {
                        Text(HTMLDisclaimer.attributedString(from: answer, baseSize: style.answerFontSize ?? 12,
                                                             fontFamily: theme.fontFamily))
                            .foregroundColor(Color(hex: style.answerColor ?? "#555555"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .background(shape.fill(Color(hex: style.itemBackground ?? "#FFFFFF")))
                .overlay(shape.stroke(Color(optionalHex: style.itemBorderColor) ?? .clear, lineWidth: 1))
            }
        }
    }
}

private struct ImageGridBlock: View {
    let block: ThemeBlock

    @Environment(\.paymentLanguage) private var language

    var body: some View {
        let style = block.style
        let gap = style.gap ?? 10
        let columns = Array(repeating: GridItem(.flexible(), spacing: gap), count: max(1, block.columns ?? 3))
        LazyVGrid(columns: columns, spacing: gap) {
            ForEach(Array(block.items.enumerated()), id: \.offset) { _, item in
                if let url = imageURL(item.imageUrl, language) {
                    Color(hex: style.itemBackground ?? "#00000000")
                        .aspectRatio(style.itemAspectRatio ?? 1, contentMode: .fit)
                        .overlay(RemoteImage(url: url, contentMode: .fill))
                        .clipShape(RoundedRectangle(cornerRadius: style.itemCornerRadius ?? 8))
                }
            }
        }
    }
}
