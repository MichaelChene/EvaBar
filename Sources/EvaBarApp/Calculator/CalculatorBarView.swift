import AppKit

@MainActor
final class CalculatorBarView: NSView {
    let expression = NSTextField()
    let result = NSTextField(wrappingLabelWithString: "0.0")
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
        result.lineBreakMode = .byCharWrapping
        result.maximumNumberOfLines = 0

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
        let centerY = bounds.maxY - CalculatorPanel.barHeight / 2 - 3
        let toolbarCenters: [CGFloat] = [64, 113, 163]
        let buttonWidth = 48 * scale
        for (button, center) in zip(tools, toolbarCenters) {
            button.frame = NSRect(x: center * scale - buttonWidth / 2, y: centerY - 16,
                                  width: buttonWidth, height: 32)
        }

        let copyCenter = round(width * 0.8675)
        let resultEnd = copyCenter - 26
        let resultWidth = singleRowResultWidth(for: width)
        let resultStart = resultEnd - resultWidth
        let height = extendedResultHeight(for: width)
        let copyY = height > 0 ? 8 + min(height, 36) / 2 : centerY
        copyButton.frame = NSRect(x: copyCenter - 17, y: copyY - 16, width: 34, height: 32)
        let feedbackStart = copyButton.frame.maxX + 5
        let feedbackWidth = max(1, floor(width - feedbackStart - 8))
        if feedback.preferredMaxLayoutWidth != feedbackWidth {
            feedback.preferredMaxLayoutWidth = feedbackWidth
        }
        feedback.frame = centeredFrame(for: feedback, x: feedbackStart, y: copyY, width: feedbackWidth)
        if height > 0 {
            result.frame = NSRect(x: 24, y: 8, width: extendedResultWidth(for: width), height: height)
        } else {
            result.frame = centeredFrame(for: result, x: resultStart, y: centerY, width: resultWidth)
        }

        let expressionStart = 220 * scale
        expression.frame = centeredFrame(
            for: expression, x: expressionStart, y: centerY + 2,
            width: max(1, (height > 0 ? width - 24 : resultStart - 18) - expressionStart)
        )
    }

    func height(fittingWidth width: CGFloat) -> CGFloat {
        let extra = extendedResultHeight(for: width)
        return CalculatorPanel.barHeight + (extra > 0 ? extra + 8 : 0)
    }

    private func singleRowResultWidth(for width: CGFloat) -> CGFloat {
        min(260, floor(width * 0.22))
    }

    private func extendedResultWidth(for width: CGFloat) -> CGFloat {
        max(1, round(width * 0.8675) - 50)
    }

    private func extendedResultHeight(for width: CGFloat) -> CGFloat {
        guard width > 0, !result.stringValue.isEmpty, let cell = result.cell, let font = result.font else { return 0 }
        let textWidth = (result.stringValue as NSString).size(withAttributes: [.font: font]).width
        guard ceil(textWidth) + 6 > singleRowResultWidth(for: width) else { return 0 }
        let bounds = NSRect(x: 0, y: 0, width: extendedResultWidth(for: width), height: .greatestFiniteMagnitude)
        return ceil(cell.cellSize(forBounds: bounds).height)
    }

    private func centeredFrame(for field: NSTextField, x: CGFloat, y: CGFloat, width: CGFloat) -> NSRect {
        let height = ceil(field.intrinsicContentSize.height)
        return NSRect(x: round(x), y: round(y - height / 2), width: round(width), height: height)
    }

    func showResult(_ text: String, errorDetail: String? = nil, preservingResult: Bool = false) {
        let isError = errorDetail != nil
        if !isError { result.stringValue = text }
        // Keep the last valid result's space while the user edits the expression.
        result.isHidden = isError && !preservingResult
        result.toolTip = result.isHidden ? nil : result.stringValue
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
