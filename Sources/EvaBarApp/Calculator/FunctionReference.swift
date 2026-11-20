import AppKit

@MainActor
enum FunctionReference {
    static func makeGrid() -> DrawerGrid {
        let operations = section(L10n.text("Operators"), [
            ("+", "addition"), ("-", "subtraction"), ("*", "multiplication (asterisk)"),
            ("/", "division"), ("%", "remainder (e.g. 4 % 3 = 1)"), ("^", "exponent (e.g. 3 ^ 2 = 9)")
        ])
        let arithmetic = section(L10n.text("Functions and constants"), [
            ("abs(x)", "absolute value of x"), ("sqrt(x)", "square root of x"),
            ("pow(x,y)", "exponent (x to the power y)"), ("mod(x,y)", "remainder of x divided by y"),
            ("ln(x)", "natural logarithm of x"), ("log(x,y)", "logarithm of x with base y"),
            ("pi", "(constant) returns the value of pi")
        ])
        let statistics = section(L10n.text("Statistics and rounding"), [
            ("min(x,y,...)", "minimum of set (x,y,...)"), ("max(x,y,...)", "maximum of set (x,y,...)"),
            ("avg(x,y,...)", "average of set (x,y,...)"), ("round(x)", "round x to the nearest integer"),
            ("floor(x)", "round x down to the nearest integer"), ("ceil(x)", "round x up to the nearest integer")
        ])
        let trigonometry = section(L10n.text("Trigonometry"), [
            ("sin(x)", "sine of x"), ("cos(x)", "cosine of x"), ("tan(x)", "tangent of x"),
            ("arcsin(x)", "arcsin (or inverse sine) of x"), ("arccos(x)", "arccos (or inverse cosine) of x"),
            ("arctan(x)", "arctan (or inverse tangent) of x"), ("atan2(y,x)", "four-quadrant inverse tangent of y & x")
        ])
        let sections = [operations, arithmetic, statistics, trigonometry]
        let minimumWidth = max(310, ceil(sections.map(\.minimumWidth).max() ?? 0))
        return DrawerGrid(sections: sections.map(\.view), columnCounts: [4, 2, 1], minimumColumnWidth: minimumWidth,
                          horizontalInset: 24, verticalInset: 15, bottomInset: 22)
    }

    private static func section(_ title: String, _ entries: [(String, String)])
        -> (view: NSStackView, minimumWidth: CGFloat) {
        let heading = NSTextField(labelWithString: title)
        heading.font = .systemFont(ofSize: 13, weight: .semibold)
        heading.textColor = .secondaryLabelColor
        let items = entries.map { syntax, meaning in
            let code = NSTextField(labelWithString: syntax)
            code.font = .systemFont(ofSize: 12, weight: .semibold)
            code.usesSingleLineMode = true
            code.lineBreakMode = .byClipping
            let badge = NSBox()
            badge.boxType = .custom
            badge.cornerRadius = 6
            badge.titlePosition = .noTitle
            badge.borderWidth = 0
            badge.fillColor = NSColor.labelColor.withAlphaComponent(0.025)
            badge.contentViewMargins = NSSize(width: 7, height: 0)
            badge.contentView = code
            let badgeWidth = ceil(code.intrinsicContentSize.width) + 17
            badge.widthAnchor.constraint(equalToConstant: badgeWidth).isActive = true
            badge.heightAnchor.constraint(equalToConstant: 17).isActive = true

            let translation = L10n.text(meaning)
            let description = NSTextField(labelWithString: translation)
            description.font = .systemFont(ofSize: 12, weight: .regular)
            description.textColor = NSColor.labelColor.withAlphaComponent(0.85)
            description.lineBreakMode = .byTruncatingTail
            description.toolTip = translation
            description.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            return (badge: badge, width: badgeWidth, description: description)
        }
        let codeWidth = items.map(\.width).max() ?? 0
        let descriptionWidth = items.map { $0.description.intrinsicContentSize.width }.max() ?? 0
        let columnSpacing: CGFloat = 8
        let rows = items.map { item in
            let codeCell = NSView()
            item.badge.translatesAutoresizingMaskIntoConstraints = false
            codeCell.addSubview(item.badge)
            NSLayoutConstraint.activate([
                codeCell.widthAnchor.constraint(equalToConstant: codeWidth),
                codeCell.heightAnchor.constraint(equalTo: item.badge.heightAnchor),
                item.badge.leadingAnchor.constraint(equalTo: codeCell.leadingAnchor),
                item.badge.centerYAnchor.constraint(equalTo: codeCell.centerYAnchor)
            ])
            let row = DrawerGrid.row([codeCell, item.description], spacing: columnSpacing)
            row.heightAnchor.constraint(equalToConstant: 22).isActive = true
            return row
        }
        let column = DrawerGrid.column([heading] + rows, spacing: 0)
        column.setCustomSpacing(6, after: heading)
        for row in rows {
            row.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        }
        let minimumWidth = max(heading.intrinsicContentSize.width, codeWidth + columnSpacing + descriptionWidth)
        return (column, minimumWidth)
    }
}
