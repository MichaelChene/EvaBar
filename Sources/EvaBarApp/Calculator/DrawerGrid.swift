import AppKit

@MainActor
final class DrawerGrid: NSView {
    private let sections: [NSView]
    private let columnCounts: [Int]
    private let minimumColumnWidth: CGFloat
    private let horizontalInset: CGFloat
    private let verticalInset: CGFloat
    private let bottomInset: CGFloat
    private let gap: CGFloat = 16

    override var isFlipped: Bool { true }

    init(sections: [NSView], columnCounts: [Int], minimumColumnWidth: CGFloat,
         horizontalInset: CGFloat, verticalInset: CGFloat, bottomInset: CGFloat) {
        self.sections = sections
        self.columnCounts = columnCounts
        self.minimumColumnWidth = minimumColumnWidth
        self.horizontalInset = horizontalInset
        self.verticalInset = verticalInset
        self.bottomInset = bottomInset
        super.init(frame: .zero)
        clipsToBounds = true
        autoresizesSubviews = false
        sections.forEach { addSubview($0) }
    }

    required init?(coder: NSCoder) { nil }

    func layoutContent(width: CGFloat) -> CGFloat {
        let available = max(1, width - 2 * horizontalInset)
        let fittingColumns = Int((available + gap) / (minimumColumnWidth + gap))
        let columns = columnCounts.first { $0 <= fittingColumns } ?? 1
        let columnWidth = (available - CGFloat(columns - 1) * gap) / CGFloat(columns)
        var y = verticalInset
        for start in stride(from: 0, to: sections.count, by: columns) {
            let row = sections[start..<min(start + columns, sections.count)]
            var rowHeight: CGFloat = 0
            for (column, section) in row.enumerated() {
                let height = ceil(section.fittingSize.height)
                let x = horizontalInset + CGFloat(column) * (columnWidth + gap)
                section.frame = NSRect(x: x, y: y, width: columnWidth, height: height)
                rowHeight = max(rowHeight, height)
            }
            y += rowHeight + gap
        }
        setFrameSize(NSSize(width: width, height: y - gap + bottomInset))
        return frame.height
    }

    static func column(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }

    static func row(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = spacing
        return stack
    }
}
