import AVFoundation
import ImageIO
import SwiftUI
import UIKit

// MARK: - Environment

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = PresentationDocument.hardcodedFallback.theme
}

private struct LanguageKey: EnvironmentKey {
    static let defaultValue = "en"
}

extension EnvironmentValues {
    var paymentTheme: ThemeTokens {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }

    /// Device language code used for copy and layout direction.
    var paymentLanguage: String {
        get { self[LanguageKey.self] }
        set { self[LanguageKey.self] = newValue }
    }
}

// MARK: - Alignment helpers

enum ThemeAlignment {
    static func text(_ raw: String?) -> TextAlignment {
        switch raw {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }

    static func frame(_ raw: String?) -> Alignment {
        switch raw {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }

    static func horizontal(_ raw: String?) -> HorizontalAlignment {
        switch raw {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }
}

// MARK: - Screen background

/// `color` (solid, or an animated gradient when `colors` has several entries), `image` or `video`,
/// with an optional `overlay` colour on top.
struct ThemeBackground: View {
    let fill: ThemeTokens.Fill

    @State private var animate = false

    var body: some View {
        ZStack {
            base
            switch fill.type {
            case "image":
                if let url = URL(string: fill.url ?? "") {
                    RemoteImage(url: url, contentMode: .fill, showsProgress: false)
                }
            case "video":
                if let url = URL(string: fill.url ?? "") {
                    LoopingVideoView(url: url)
                }
            default:
                EmptyView()
            }
            if let overlay = Color(optionalHex: fill.overlay) {
                overlay
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var base: some View {
        let colors = fill.gradientColors.map(Color.init(hex:))
        if fill.type == "color", colors.count > 1 {
            LinearGradient(colors: colors,
                           startPoint: animate ? .topLeading : .bottomLeading,
                           endPoint: animate ? .bottomTrailing : .topTrailing)
                .onAppear {
                    withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { animate = true }
                }
        } else {
            Color(hex: fill.color ?? "#F2F2F7")
        }
    }
}

/// Muted, looping background video.
struct LoopingVideoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.play(url)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    static func dismantleUIView(_ uiView: PlayerView, coordinator: ()) {
        uiView.stop()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var looper: AVPlayerLooper?
        private var player: AVQueuePlayer?

        func play(_ url: URL) {
            let player = AVQueuePlayer()
            player.isMuted = true
            player.preventsDisplaySleepDuringVideoPlayback = false
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            (layer as? AVPlayerLayer)?.player = player
            (layer as? AVPlayerLayer)?.videoGravity = .resizeAspectFill
            self.player = player
            player.play()
        }

        func stop() {
            player?.pause()
            looper = nil
            player = nil
        }
    }
}

// MARK: - Buttons

/// Solid, linear-gradient or radial-gradient fill from `button.background`.
struct ThemeButtonFill: View {
    let fill: ThemeTokens.Fill
    let disabledColor: String
    let isEnabled: Bool

    var body: some View {
        let colors = fill.gradientColors.map(Color.init(hex:))
        if !isEnabled {
            Color(hex: disabledColor)
        } else if fill.type == "linear", colors.count > 1 {
            LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
        } else if fill.type == "radial", colors.count > 1 {
            GeometryReader { geo in
                RadialGradient(colors: colors, center: .center, startRadius: 0,
                               endRadius: max(geo.size.width, geo.size.height) / 2)
            }
        } else {
            Color(hex: fill.color ?? "#0A84FF")
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var isLoading = false
    var isEnabled = true
    let action: () -> Void

    @Environment(\.paymentTheme) private var theme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.button.cornerRadius)
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(hex: theme.button.textColor)))
                }
                Text(theme.button.title(title))
                    .font(theme.font(size: theme.button.fontSize, weight: theme.buttonFontWeight))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(Color(hex: theme.button.textColor))
            .frame(maxWidth: .infinity)
            .frame(minHeight: theme.button.height)
            .background(ThemeButtonFill(fill: theme.button.background,
                                        disabledColor: theme.button.disabledBackground,
                                        isEnabled: isEnabled && !isLoading))
            .clipShape(shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }
}

struct CloseButton: View {
    let color: Color
    var background: Color = Color.secondary.opacity(0.15)
    let action: () -> Void

    @Environment(\.paymentLanguage) private var language

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(Circle().fill(background))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.text(.close, language)))
    }
}

// MARK: - Fields

struct FieldChrome: View {
    var borderColor: Color?
    var lineWidth: Double?

    @Environment(\.paymentTheme) private var theme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.field.cornerRadius)
        shape.fill(Color(hex: theme.field.background))
            .overlay(shape.stroke(borderColor ?? Color(hex: theme.field.borderColor).opacity(theme.field.borderOpacity),
                                  lineWidth: lineWidth ?? theme.field.borderWidth))
    }
}

/// Small label drawn over the field's top border (theme `field.floatingLabel`).
struct FloatingLabel: View {
    let text: String
    let style: ThemeTokens.Field.FloatingLabel

    @Environment(\.paymentTheme) private var theme

    var body: some View {
        Text(text)
            .font(theme.font(size: style.fontSize ?? 13, weight: .medium))
            .foregroundColor(Color(hex: style.color))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: style.cornerRadius ?? 4)
                .fill(Color(optionalHex: style.background) ?? Color(hex: theme.field.background)))
            .offset(y: -9)
            .padding(.leading, 12)
    }
}

// MARK: - Inline error

struct InlineErrorBanner: View {
    let message: String
    let onTap: () -> Void

    @Environment(\.paymentTheme) private var theme

    var body: some View {
        let style = theme.text.error
        Text(HTMLDisclaimer.attributedString(from: message, baseSize: style.fontSize, baseWeight: .medium,
                                             fontFamily: theme.fontFamily))
            .foregroundColor(Color(hex: style.color))
            .multilineTextAlignment(.center)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(Color(hex: style.background ?? "#E53935"))
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius ?? 12))
            .onTapGesture(perform: onTap)
            .accessibilityAddTraits(.isStaticText)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - HTML text

/// Renders decoded backend HTML with the theme's disclaimer style. Links open in a sheet.
struct HTMLText: View {
    let html: String
    let style: ThemeTokens.TextStyle
    let onOpenURL: (URL) -> Void

    @Environment(\.paymentTheme) private var theme

    var body: some View {
        let attributed = HTMLDisclaimer.attributedString(from: html, baseSize: style.fontSize,
                                                         fontFamily: theme.fontFamily)
        let text = Text(attributed)
            .foregroundColor(Color(hex: style.color))
            .lineSpacing(max(0, ((style.lineHeight ?? 1.2) - 1) * style.fontSize))
            .multilineTextAlignment(ThemeAlignment.text(style.alignment))
            .frame(maxWidth: .infinity, alignment: ThemeAlignment.frame(style.alignment))
            .fixedSize(horizontal: false, vertical: true)
        if #available(iOS 16, *) {
            text.environment(\.openURL, OpenURLAction { url in
                onOpenURL(url)
                return .handled
            })
        } else {
            text
        }
    }
}

// MARK: - Remote images

/// Downloads, downsamples and caches remote images.
final class RemoteImageCache: @unchecked Sendable {
    static let shared = RemoteImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }

    func load(_ url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        if let cached = image(for: url) { return cached }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        request.httpMethod = "GET"
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return nil }
        guard let image = Self.downsample(data, maxPixelSize: maxPixelSize) ?? UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    static func downsample(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct RemoteImage: View {
    let url: URL
    var contentMode: ContentMode = .fit
    var showsProgress = true
    var tint: Color = .secondary

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if showsProgress && !failed {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: tint))
            }
        }
        .task(id: url) {
            if let cached = RemoteImageCache.shared.image(for: url) {
                image = cached
                return
            }
            let maxPixel = UIScreen.main.bounds.width * UIScreen.main.scale * 2
            image = await RemoteImageCache.shared.load(url, maxPixelSize: maxPixel)
            failed = image == nil
        }
    }
}

// MARK: - Shapes

struct BottomRoundedRectangle: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect,
                          byRoundingCorners: [.bottomLeft, .bottomRight],
                          cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}
