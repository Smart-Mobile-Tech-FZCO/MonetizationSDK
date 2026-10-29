import SwiftUI
import UIKit

struct PhoneScreen: View {
    @ObservedObject var flow: FlowCoordinator
    let content: PhoneScreenContent

    var body: some View {
        FormScreen(
            headerPicURL: content.headerPicURL,
            serviceName: content.serviceName,
            topHTML: [content.headerHTML].compactMap { $0 },
            middleHTML: content.middleHTML,
            footerHTML: content.footerHTML,
            legalLinks: content.legalLinks,
            buttonTitle: content.buttonTitle,
            isSubmitting: flow.isSubmitting,
            secondaryLinkTitle: nil,
            countryISO: content.countryISO,
            inlineError: flow.inlineError,
            onSubmit: { Task { await flow.submitPhone() } },
            onSecondaryLink: {},
            onDismissError: flow.dismissInlineError,
            onClose: flow.close
        ) {
            PhoneField(flow: flow, content: content)
        }
    }
}

/// Dial code (locked or picked) plus the national number. Always left-to-right.
struct PhoneField: View {
    @ObservedObject var flow: FlowCoordinator
    let content: PhoneScreenContent

    @Environment(\.paymentTheme) private var theme
    @Environment(\.paymentLanguage) private var language

    private var dialCode: String { flow.dialCodeForPhone }
    private var country: Country {
        if content.lockedDialCode != nil, let iso = CountryCatalog.country(forISO: content.countryISO),
           iso.dial == "+" + dialCode {
            return iso
        }
        return CountryCatalog.country(forDial: dialCode)
    }
    private var isValid: Bool {
        PhoneNumberValidator.shared.validate(local: flow.phoneNumber, dialCode: dialCode).phn != nil
    }

    var body: some View {
        HStack(spacing: 8) {
            dialSelector
            numberField
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder
    private var dialSelector: some View {
        let label = HStack(spacing: 4) {
            Text(country.shortLabel)
                .font(theme.font(size: theme.field.fontSize, weight: .medium))
            if content.lockedDialCode == nil {
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
            }
        }
        .foregroundColor(Color(hex: theme.field.dialCodeColor))
        .padding(.horizontal, 12)
        .frame(height: theme.field.height)
        .background(FieldChrome())
        .fixedSize(horizontal: true, vertical: false)

        if content.lockedDialCode != nil {
            label.accessibilityLabel(Text("\(country.name) \(country.dial)"))
        } else {
            Menu {
                ForEach(CountryCatalog.all) { option in
                    Button(option.rowLabel) { flow.selectedDialCode = option.dial.filter(\.isNumber) }
                }
            } label: { label }
        }
    }

    private var numberField: some View {
        let icons = theme.field.icons
        let placeholder = theme.field.placeholderText?.phone?.nonEmptyTrimmed ?? content.placeholder
        return HStack(spacing: 8) {
            if let icons {
                Image(systemName: "phone.fill")
                    .foregroundColor(Color(hex: (flow.phoneNumber.isEmpty ? icons.phoneColor : icons.phoneActiveColor) ?? "#464646"))
            }
            LTRPhoneTextField(
                placeholder: placeholder,
                text: Binding(get: { flow.phoneNumber }, set: { flow.phoneNumber = sanitize($0) }),
                fontSize: theme.field.fontSize,
                textColor: UIColor(Color(hex: theme.field.textColor)),
                placeholderColor: UIColor(Color(hex: theme.field.placeholderColor)),
                onSubmit: { Task { await flow.submitPhone() } }
            )
            if let icons {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: (isValid ? icons.checkValidColor : icons.checkColor) ?? "#D9D9D9"))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: theme.field.height)
        .frame(maxWidth: .infinity)
        .background(FieldChrome())
        .overlay(alignment: .topLeading) {
            if let floating = theme.field.floatingLabel, let text = floating.phoneText?.resolve(language).nonEmptyTrimmed {
                FloatingLabel(text: text, style: floating)
            }
        }
    }

    /// Digits only; drops a pasted `+<dial code>` prefix and caps the length.
    private func sanitize(_ raw: String) -> String {
        var digits = raw.westernDigits.filter(\.isNumber)
        if raw.trimmingCharacters(in: .whitespaces).hasPrefix("+") || raw.hasPrefix("00") {
            if digits.hasPrefix("00") { digits.removeFirst(2) }
            if digits.hasPrefix(dialCode), digits.count > dialCode.count { digits.removeFirst(dialCode.count) }
        }
        if let max = PhoneNumberValidator.shared.maxNationalDigits(dialCode: dialCode) {
            let limit = digits.hasPrefix("0") ? max + 1 : max
            digits = String(digits.prefix(limit))
        }
        return digits
    }
}

/// Phone entry that stays left-to-right even in RTL layouts or with an Arabic keyboard.
struct LTRPhoneTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var fontSize: Double
    var textColor: UIColor
    var placeholderColor: UIColor
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.keyboardType = .phonePad
        field.textContentType = .telephoneNumber
        field.autocorrectionType = .no
        field.semanticContentAttribute = .forceLeftToRight
        field.textAlignment = .left
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.inputAccessoryView = context.coordinator.makeToolbar(target: field)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onSubmit = onSubmit
        if field.text != text { field.text = text }

        let styleKey = "\(placeholder)|\(fontSize)|\(textColor)|\(placeholderColor)"
        guard context.coordinator.styleKey != styleKey else { return }
        context.coordinator.styleKey = styleKey
        let font = UIFont.systemFont(ofSize: fontSize)
        field.font = font
        field.textColor = textColor
        field.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
            .font: font, .foregroundColor: placeholderColor,
        ])
        field.accessibilityLabel = placeholder
    }

    @MainActor
    final class Coordinator: NSObject {
        var text: Binding<String>
        var styleKey = ""
        var onSubmit: () -> Void = {}

        init(text: Binding<String>) { self.text = text }

        @objc func editingChanged(_ field: UITextField) {
            let raw = field.text ?? ""
            text.wrappedValue = raw
            if field.text != text.wrappedValue { field.text = text.wrappedValue }
        }

        /// `.phonePad` has no return key; add a Done button.
        func makeToolbar(target: UITextField) -> UIToolbar {
            let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
            bar.items = [
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(barButtonSystemItem: .done, target: target, action: #selector(UIResponder.resignFirstResponder)),
            ]
            bar.sizeToFit()
            return bar
        }
    }
}
