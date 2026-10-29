import SwiftUI

/// Decodes the backend's form-URL-encoded HTML and renders a safe subset of it as `AttributedString`.
enum HTMLDisclaimer {

    /// `%3ch4+style%3d...` → `<h4 style=...`: `+` becomes a space, then percent-decoding.
    /// Strings that are already plain HTML (no escapes) are returned unchanged.
    static func formURLDecode(_ raw: String) -> String {
        let hasEscapes = raw.range(of: "%[0-9A-Fa-f]{2}", options: .regularExpression) != nil
        guard hasEscapes || !raw.contains("<") else { return raw }
        let spaced = raw.replacingOccurrences(of: "+", with: " ")
        return spaced.removingPercentEncoding ?? spaced
    }

    /// Decoded HTML, or `nil` if it has no visible text.
    static func decodedNonEmpty(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let html = formURLDecode(raw)
        return plainText(html).isEmpty ? nil : html
    }

    static func plainText(_ html: String) -> String {
        String(attributedString(from: html).characters).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let headingScale: [CGFloat] = [2.0, 1.5, 1.17, 1.0, 0.83, 0.67]
    private static let blockTags: Set<String> = [
        "p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "li", "ul", "ol", "center",
        "table", "tr", "section", "header", "footer", "blockquote", "article",
    ]
    private static let voidTags: Set<String> = [
        "br", "hr", "img", "input", "meta", "link", "wbr", "source", "col", "area", "base",
    ]
    private static let skippedTags: Set<String> = ["script", "style", "head", "title"]

    private struct Style {
        var bold = false
        var italic = false
        var underline = false
        var strike = false
        var link: URL?
        var color: Color?
        var sizeScale: CGFloat = 1
    }

    /// Renders already-decoded HTML. Supports headings, bold/italic/underline/strike, links,
    /// `<font color>`, inline `color`/`font-weight`/`font-style`/`text-decoration`, lists and line breaks.
    static func attributedString(from html: String,
                                 baseSize: CGFloat = 14,
                                 baseWeight: Font.Weight = .regular,
                                 fontFamily: String? = nil) -> AttributedString {
        var result = AttributedString()
        var style = Style()
        var stack: [(tag: String, saved: Style)] = []
        var pendingBreak = false
        var lastWasSpace = true
        var skipDepth = 0

        func trimTrailingSpace() {
            while let last = result.characters.last, last == " " {
                result.removeSubrange(result.index(result.endIndex, offsetByCharacters: -1)..<result.endIndex)
            }
        }

        func lineBreak() {
            if !result.characters.isEmpty { pendingBreak = true }
            lastWasSpace = true
        }

        func append(_ text: String) {
            var collapsed = ""
            for ch in text {
                if ch == " " || ch == "\n" || ch == "\t" || ch == "\r" {
                    if !lastWasSpace { collapsed.append(" "); lastWasSpace = true }
                } else {
                    collapsed.append(ch)
                    lastWasSpace = false
                }
            }
            guard !collapsed.isEmpty else { return }
            if pendingBreak {
                trimTrailingSpace()
                result.append(AttributedString("\n"))
                pendingBreak = false
            }
            var piece = AttributedString(collapsed)
            var font = ThemeFont.font(family: fontFamily, size: baseSize * style.sizeScale,
                                      weight: style.bold ? .bold : baseWeight)
            if style.italic { font = font.italic() }
            // Type subscripts instead of key paths: attribute key paths are not Sendable.
            piece[AttributeScopes.SwiftUIAttributes.FontAttribute.self] = font
            if style.underline { piece[AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = .single }
            if style.strike { piece[AttributeScopes.SwiftUIAttributes.StrikethroughStyleAttribute.self] = .single }
            if let color = style.color { piece[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = color }
            if let link = style.link { piece[AttributeScopes.FoundationAttributes.LinkAttribute.self] = link }
            result.append(piece)
        }

        guard let regex = try? NSRegularExpression(pattern: "<!--.*?-->|<[^>]+>|[^<]+|<",
                                                   options: [.dotMatchesLineSeparators]) else {
            return AttributedString(html)
        }
        let ns = html as NSString

        for match in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let token = ns.substring(with: match.range)

            guard token.hasPrefix("<"), token.count > 1 else {
                if skipDepth == 0 { append(decodeEntities(token)) }
                continue
            }
            if token.hasPrefix("<!") { continue }

            let isClosing = token.hasPrefix("</")
            let inner = token.dropFirst(isClosing ? 2 : 1).dropLast()
            let name = String(inner.prefix { $0.isLetter || $0.isNumber }).lowercased()
            guard !name.isEmpty else { continue }
            let attrs = String(inner.dropFirst(name.count))

            if skippedTags.contains(name) {
                if isClosing { skipDepth = max(0, skipDepth - 1) } else if !attrs.hasSuffix("/") { skipDepth += 1 }
                continue
            }
            if skipDepth > 0 { continue }

            if isClosing {
                if let idx = stack.lastIndex(where: { $0.tag == name }) {
                    style = stack[idx].saved
                    stack.removeSubrange(idx...)
                }
                if blockTags.contains(name) { lineBreak() }
                continue
            }

            switch name {
            case "br":
                if result.characters.isEmpty && !pendingBreak {
                    lastWasSpace = true
                } else {
                    if pendingBreak { result.append(AttributedString("\n")) }
                    pendingBreak = true
                    lastWasSpace = true
                }
                continue
            case "hr":
                lineBreak()
                continue
            default:
                break
            }
            if voidTags.contains(name) { continue }
            if blockTags.contains(name) { lineBreak() }

            let saved = style
            var next = style
            switch name {
            case "b", "strong":
                next.bold = true
            case "i", "em", "cite":
                next.italic = true
            case "u", "ins":
                next.underline = true
            case "s", "strike", "del":
                next.strike = true
            case "a":
                if let href = attribute("href", in: attrs),
                   let url = URL(string: href.trimmingCharacters(in: .whitespaces)),
                   let scheme = url.scheme?.lowercased(), scheme != "javascript" {
                    next.link = url
                }
            case "font":
                if let c = attribute("color", in: attrs).flatMap(parseColor) { next.color = c }
            case "h1", "h2", "h3", "h4", "h5", "h6":
                let level = Int(name.dropFirst()) ?? 4
                next.bold = true
                next.sizeScale = headingScale[level - 1]
            default:
                break
            }
            if let css = attribute("style", in: attrs) { applyCSS(css, to: &next) }

            if !attrs.hasSuffix("/") {
                stack.append((name, saved))
                style = next
            }
            if name == "li" { append("• "); lastWasSpace = true }
        }

        trimTrailingSpace()
        return result
    }

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        let named: [String: String] = [
            "nbsp": "\u{00A0}", "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
            "copy": "©", "reg": "®", "trade": "™", "hellip": "…", "mdash": "—", "ndash": "–",
            "laquo": "«", "raquo": "»", "lsquo": "\u{2018}", "rsquo": "\u{2019}",
            "ldquo": "\u{201C}", "rdquo": "\u{201D}", "bull": "•", "euro": "€", "pound": "£",
        ]
        guard let regex = try? NSRegularExpression(pattern: "&(#[xX]?[0-9A-Fa-f]+|[A-Za-z]+);") else { return text }
        let ns = text as NSString
        var out = ""
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let body = ns.substring(with: match.range(at: 1))
            var replacement: String?
            if body.hasPrefix("#") {
                let digits = body.dropFirst()
                let value = digits.first == "x" || digits.first == "X"
                    ? UInt32(digits.dropFirst(), radix: 16)
                    : UInt32(digits, radix: 10)
                if let value, let scalar = Unicode.Scalar(value) { replacement = String(Character(scalar)) }
            } else {
                replacement = named[body.lowercased()]
            }
            out += replacement ?? ns.substring(with: match.range)
            cursor = match.range.location + match.range.length
        }
        out += ns.substring(from: cursor)
        return out
    }

    private static func attribute(_ name: String, in attrs: String) -> String? {
        let pattern = "\\b\(name)\\s*=\\s*(\"([^\"]*)\"|'([^']*)'|([^\\s>]+))"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = attrs as NSString
        guard let m = regex.firstMatch(in: attrs, range: NSRange(location: 0, length: ns.length)) else { return nil }
        for group in 2...4 where m.range(at: group).location != NSNotFound {
            return decodeEntities(ns.substring(with: m.range(at: group)))
        }
        return nil
    }

    private static func applyCSS(_ css: String, to style: inout Style) {
        for declaration in css.split(separator: ";") {
            let parts = declaration.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = parts[1].replacingOccurrences(of: "!important", with: "")
                .trimmingCharacters(in: .whitespaces).lowercased()
            switch key {
            case "color":
                if let c = parseColor(value) { style.color = c }
            case "font-weight":
                if value == "bold" || value == "bolder" || (Int(value) ?? 0) >= 600 {
                    style.bold = true
                } else if value == "normal" || value == "lighter" || (Int(value) ?? 1000) < 600 {
                    style.bold = false
                }
            case "font-style":
                style.italic = value.contains("italic") || value.contains("oblique")
            case "text-decoration", "text-decoration-line":
                if value.contains("underline") { style.underline = true }
                if value.contains("line-through") { style.strike = true }
                if value == "none" { style.underline = false; style.strike = false }
            default:
                break
            }
        }
    }

    private static func parseColor(_ raw: String) -> Color? {
        let value = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if value.hasPrefix("#") {
            let hex = String(value.dropFirst())
            guard [3, 6].contains(hex.count), UInt64(hex, radix: 16) != nil else { return nil }
            return Color(hex: hex)
        }
        if value.hasPrefix("rgb") {
            let nums = value.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
                .compactMap(Double.init)
            guard nums.count >= 3 else { return nil }
            return Color(.sRGB, red: nums[0] / 255, green: nums[1] / 255, blue: nums[2] / 255,
                         opacity: nums.count > 3 ? nums[3] : 1)
        }
        let named: [String: String] = [
            "black": "000000", "white": "FFFFFF", "red": "FF0000", "green": "008000",
            "blue": "0000FF", "gray": "808080", "grey": "808080", "orange": "FFA500",
            "yellow": "FFFF00", "purple": "800080", "navy": "000080", "silver": "C0C0C0",
        ]
        return named[value].map { Color(hex: $0) }
    }
}
