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

    public func string(forExpression source: String) throws -> String {
        let input = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return string(0) }
        switch try Expression.evaluateForDisplay(input) {
        case .exact(let value): return decimalString(value)
        case .approximate(let value): return string(value)
        }
    }

    public func string(_ value: Double) -> String {
        if value == 0 { return "0.0" }
        let magnitude = abs(value)
        if places > 0 && magnitude < pow(10, -Double(places)) {
            return plainDecimal(value)
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.decimalSeparator = decimal.rawValue
        formatter.usesGroupingSeparator = grouping != .none && grouping != decimal
        formatter.groupingSeparator = grouping.rawValue
        formatter.maximumFractionDigits = places
        formatter.roundingMode = .halfUp
        let rounded = formatter.string(from: NSNumber(value: value)) ?? plainDecimal(value)
        return rounded == "-0" ? "0" : rounded
    }

    private func decimalString(_ value: ExactDecimal) -> String {
        guard !value.isZero else { return "0.0" }
        let precision = min(Self.decimalPlaces.upperBound, max(0, places))
        let parts = value.decimalParts(places: precision)
        let whole = parts.whole.drop(while: { $0 == 0 })
        let fraction = parts.fraction
        let isBelowPrecision = precision > 0 && whole.isEmpty && fraction.prefix(precision).allSatisfy { $0 == 0 }
        let visiblePlaces = isBelowPrecision ? fraction.count : min(precision, fraction.count)
        var digits = whole.isEmpty ? [UInt8(0)] : Array(whole)
        digits.append(contentsOf: fraction.prefix(visiblePlaces))
        if let nextDigit = fraction.dropFirst(visiblePlaces).first, nextDigit >= 5 {
            var index = digits.count - 1
            while digits[index] == 9 && index > 0 {
                digits[index] = 0
                index -= 1
            }
            if digits[index] == 9 {
                digits[index] = 0
                digits.insert(1, at: 0)
            } else {
                digits[index] += 1
            }
        }

        if digits.allSatisfy({ $0 == 0 }) { return "0" }
        let split = digits.count - visiblePlaces
        let integer = digits[..<split].map { $0 + UInt8(ascii: "0") }
        let formattedInteger: String
        if grouping != .none && grouping != decimal {
            formattedInteger = stride(from: 0, to: split, by: 3).reversed().map { offset in
                String(decoding: integer[max(0, split - offset - 3)..<(split - offset)], as: UTF8.self)
            }.joined(separator: grouping.rawValue)
        } else {
            formattedInteger = String(decoding: integer, as: UTF8.self)
        }
        let fractionalDigits = digits[split...].reversed().drop(while: { $0 == 0 }).reversed()
            .map { $0 + UInt8(ascii: "0") }
        let suffix = fractionalDigits.isEmpty ? "" : decimal.rawValue + String(decoding: fractionalDigits, as: UTF8.self)
        return (value.isNegative ? "-" : "") + formattedInteger + suffix
    }

    private func plainDecimal(_ value: Double) -> String {
        let parts = String(value.magnitude).split(separator: "e")
        let sign = value < 0 ? "-" : ""
        guard parts.count == 2, let exponent = Int(parts[1]) else {
            return sign + parts[0].replacingOccurrences(of: ".", with: decimal.rawValue)
        }
        let significand = parts[0].split(separator: ".")
        let digits = significand.joined()
        let point = significand[0].count + exponent
        if point <= 0 {
            return sign + "0" + decimal.rawValue + String(repeating: "0", count: -point) + digits
        }
        if point >= digits.count {
            return sign + digits + String(repeating: "0", count: point - digits.count)
        }
        return sign + digits.prefix(point) + decimal.rawValue + digits.dropFirst(point)
    }
}
