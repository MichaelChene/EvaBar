import Foundation

public enum NumberSeparator: String, Sendable {
    case period = "."
    case comma = ","
    case none = ""
}

public struct ResultFormatting: Sendable {
    public static let defaultPlaces = 10
    public static let decimalPlaces = 0...15

    public let places: Int
    public var decimal: NumberSeparator
    public var grouping: NumberSeparator

    public init(places: Int, decimal: NumberSeparator = .period, grouping: NumberSeparator = .none) {
        self.places = places
        self.decimal = decimal
        self.grouping = grouping
    }

    public func string(_ value: Double) -> String {
        if value == 0 { return "0.0" }
        let magnitude = abs(value)
        if magnitude >= 1e15 || (places > 0 && magnitude < pow(10, -Double(places))) {
            return String(format: "%.12g", locale: Locale(identifier: "en_US_POSIX"), value)
                .lowercased()
                .replacingOccurrences(of: ".", with: decimal.rawValue)
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.decimalSeparator = decimal.rawValue
        formatter.usesGroupingSeparator = grouping != .none && grouping != decimal
        formatter.groupingSeparator = grouping.rawValue
        formatter.maximumFractionDigits = places
        formatter.roundingMode = .halfUp
        let rounded = formatter.string(from: NSNumber(value: value)) ?? String(value)
        return rounded == "-0" ? "0" : rounded
    }
}
