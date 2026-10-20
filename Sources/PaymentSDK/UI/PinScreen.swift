import SwiftUI

struct PinScreen: View {
    @ObservedObject var flow: FlowCoordinator
    let content: PinScreenContent

    var body: some View {
        FormScreen(
            headerPicURL: content.headerPicURL,
            serviceName: content.serviceName,
            topHTML: [content.otpTopHTML, content.headerHTML].compactMap { $0 },
            middleHTML: content.middleHTML,
            footerHTML: content.footerHTML,
            legalLinks: content.legalLinks,
            buttonTitle: content.buttonTitle,
            isSubmitting: flow.isSubmitting,
            secondaryLinkTitle: content.wrongNumberTitle,
            countryISO: flow.countryISO,
            inlineError: flow.inlineError,
            onSubmit: { Task { await flow.submitPin() } },
            onSecondaryLink: flow.editPhoneNumber,
            onDismissError: flow.dismissInlineError,
            onClose: flow.close
        ) {
            PinBoxesField(text: $flow.pin, length: content.pinLength, numeric: content.usesNumericKeyboard)
        }
    }
}

/// One box per PIN character over a hidden text field (keeps one-time-code autofill working).
struct PinBoxesField: View {
    @Binding var text: String
    let length: Int
    let numeric: Bool

    @Environment(\.paymentTheme) private var theme
    @Environment(\.paymentLanguage) private var language
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            TextField("", text: Binding(get: { text }, set: { text = sanitize($0) }))
                .keyboardType(numeric ? .numberPad : .asciiCapable)
                .textContentType(.oneTimeCode)
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)
                .focused($focused)
                .foregroundColor(.clear)
                .accentColor(.clear)
                .frame(height: theme.field.height)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text(placeholderLabel))

            HStack(spacing: length > 6 ? 6 : 10) {
                ForEach(0..<length, id: \.self) { index in box(at: index) }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
        .overlay(alignment: .topLeading) {
            if let floating = theme.field.floatingLabel, let label = floating.pinText?.resolve(language).nonEmptyTrimmed {
                FloatingLabel(text: label, style: floating)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.text(.close, language)) { focused = false }
            }
        }
    }

    private var placeholderLabel: String {
        theme.field.floatingLabel?.pinText?.resolve(language) ?? ""
    }

    private func sanitize(_ raw: String) -> String {
        let normalized = raw.westernDigits
        let allowed = numeric
            ? normalized.filter { $0.isASCII && $0.isNumber }
            : normalized.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return String(allowed.prefix(length))
    }

    private func box(at index: Int) -> some View {
        let chars = Array(text)
        let hasChar = index < chars.count
        let isCurrent = index == min(chars.count, length - 1) && focused
        let shape = RoundedRectangle(cornerRadius: theme.field.cornerRadius)
        let placeholder = theme.field.placeholderText?.pin.flatMap { Array($0) }
        return Text(hasChar ? String(chars[index]) : placeholder.map { index < $0.count ? String($0[index]) : "" } ?? "")
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundColor(Color(hex: hasChar ? theme.field.textColor : theme.field.placeholderColor))
            .frame(maxWidth: .infinity)
            .frame(height: theme.field.height)
            .background(shape.fill(Color(hex: theme.field.otpBoxBackground)))
            .overlay(shape.stroke(Color(hex: isCurrent ? theme.field.otpFocusBorderColor : theme.field.otpBoxBorderColor),
                                  lineWidth: isCurrent ? 2 : max(theme.field.borderWidth, 1)))
    }
}
