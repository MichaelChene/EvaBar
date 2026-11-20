import AppKit

@MainActor
final class CalculatorBarView: NSView {
    let expression = NSTextField()
    let result = NSTextField(labelWithString: "0.0")
    let moreButton = NSButton()
    let lockButton = NSButton()
    let helpButton = NSButton()
    let copyButton = NSButton()
    private let feedback = NSTextField(wrappingLabelWithString: "")
    private var tools: [NSButton] { [moreButton, lockButton, helpButton] }

    init() {
        super.init(frame: .zero)

        let inputFont = NSFont.systemFont(ofSize: 24, weight: .light)
        expression.font = inputFont
        expression.isBordered = false
        expression.isBezeled = false
        expression.drawsBackground = false
        expression.focusRingType = .none
        expression.usesSingleLineMode = true
        expression.cell?.isScrollable = true
        expression.cell?.sendsActionOnEndEditing = false

        result.alignment = .right
        result.font = .systemFont(ofSize: 28, weight: .semibold)
        result.textColor = NSColor(named: "TextPrimary") ?? .labelColor
        result.lineBreakMode = .byTruncatingMiddle
        result.maximumNumberOfLines = 1

        feedback.font = .systemFont(ofSize: 12, weight: .medium)
        feedback.maximumNumberOfLines = 2
        feedback.cell?.truncatesLastVisibleLine = true
        feedback.isHidden = true
        (tools + [expression, result, copyButton, feedback]).forEach { addSubview($0) }
        updateLocalization()
    }

    required init?(coder: NSCoder) { nil }

    func updateLocalization() {
        expression.placeholderAttributedString = NSAttributedString(
            string: L10n.text("Start typing…"),
            attributes: [
                .font: NSFont.systemFont(ofSize: 24, weight: .light),
                .foregroundColor: NSColor.labelColor.withAlphaComponent(0.26)
            ]
        )
        expression.setAccessibilityLabel(L10n.text("Expression"))
        result.setAccessibilityLabel(L10n.text("Result"))
    }

    override func layout() {
        super.layout()
        let width = bounds.width
        let scale = min(1, width / 1200)
        let centerY = bounds.midY - 3
        let toolbarCenters: [CGFloat] = [64, 113, 163]
        let buttonWidth = 48 * scale
        for (button, center) in zip(tools, toolbarCenters) {
            button.frame = NSRect(x: center * scale - buttonWidth / 2, y: centerY - 16,
                                  width: buttonWidth, height: 32)
        }

        let copyCenter = round(width * 0.8675)
        copyButton.frame = NSRect(x: copyCenter - 17, y: centerY - 16, width: 34, height: 32)
        let feedbackStart = copyButton.frame.maxX + 5
        let feedbackWidth = max(1, floor(width - feedbackStart - 8))
        if feedback.preferredMaxLayoutWidth != feedbackWidth {
            feedback.preferredMaxLayoutWidth = feedbackWidth
        }
        feedback.frame = centeredFrame(for: feedback, x: feedbackStart, y: centerY, width: feedbackWidth)
        let resultWidth = min(260, width * 0.22)
        let resultStart = copyCenter - 26 - resultWidth
        result.frame = centeredFrame(for: result, x: resultStart, y: centerY, width: resultWidth)

        let expressionStart = 220 * scale
        expression.frame = centeredFrame(
            for: expression, x: expressionStart, y: centerY + 2,
            width: max(1, resultStart - expressionStart - 18)
        )
    }

    private func centeredFrame(for field: NSTextField, x: CGFloat, y: CGFloat, width: CGFloat) -> NSRect {
        let height = ceil(field.intrinsicContentSize.height)
        return NSRect(x: round(x), y: round(y - height / 2), width: round(width), height: height)
    }

    func showResult(_ text: String, errorDetail: String? = nil) {
        let isError = errorDetail != nil
        result.stringValue = isError ? "" : text
        result.toolTip = isError ? nil : text
        copyButton.isEnabled = !isError
        showFeedback(isError ? text : nil, errorDetail: errorDetail)
    }

    func showCopyConfirmation(_ visible: Bool) {
        showFeedback(visible ? L10n.text("Copied!") : nil)
    }

    private func showFeedback(_ text: String?, errorDetail: String? = nil) {
        feedback.stringValue = text ?? ""
        feedback.toolTip = errorDetail
        feedback.textColor = errorDetail == nil ? result.textColor : .systemRed
        feedback.isHidden = text == nil
        needsLayout = true
    }
}
