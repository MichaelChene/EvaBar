import Foundation

// A bounded rational keeps finite decimal input and arithmetic exact until display rounding.
struct ExactDecimal {
    private static let digitLimit = 1024
    private let numerator: DecimalMagnitude
    private let denominator: DecimalMagnitude
    private let negative: Bool

    init(_ literal: String) throws {
        let parts = literal.split(separator: "e", omittingEmptySubsequences: false)
        let mantissa = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        let digits = mantissa.joined().utf8.map { $0 - UInt8(ascii: "0") }
        guard !digits.isEmpty else { throw CalculationError.invalidNumber }
        let magnitude = DecimalMagnitude(digits)
        if magnitude.isZero {
            self.init(reduced: .zero, denominator: .one, negative: false)
            return
        }
        let exponent: Int
        if parts.count == 2 {
            guard let parsed = Int(parts[1]), (-Self.digitLimit...Self.digitLimit).contains(parsed) else {
                throw CalculationError.overflow
            }
            exponent = parsed
        } else {
            exponent = 0
        }
        let scale = (mantissa.count == 2 ? mantissa[1].count : 0) - exponent
        try self.init(magnitude.shifted(by: max(0, -scale)),
                      DecimalMagnitude.one.shifted(by: max(0, scale)), negative: false)
    }

    private init(_ numerator: DecimalMagnitude, _ denominator: DecimalMagnitude, negative: Bool) throws {
        if numerator.isZero {
            self.init(reduced: .zero, denominator: .one, negative: false)
            return
        }
        let removed = min(numerator.trailingZeros, denominator.trailingZeros)
        var top = numerator.removingTrailingZeros(removed)
        var bottom = denominator.removingTrailingZeros(removed)
        if top == bottom {
            self.init(reduced: .one, denominator: .one, negative: negative)
            return
        }
        if max(top.digits.count, bottom.digits.count) > Self.digitLimit && bottom != .one {
            let factor = top.commonDivisor(with: bottom)
            if factor != .one {
                top = top.divided(by: factor).quotient
                bottom = bottom.divided(by: factor).quotient
            }
        }
        guard max(top.digits.count, bottom.digits.count) <= Self.digitLimit else {
            throw CalculationError.expressionTooComplex
        }
        self.init(reduced: top, denominator: bottom, negative: negative)
    }

    private init(reduced: DecimalMagnitude, denominator: DecimalMagnitude, negative: Bool) {
        self.numerator = reduced
        self.denominator = denominator
        self.negative = negative
    }

    private static let one = Self(reduced: .one, denominator: .one, negative: false)
    var isZero: Bool { numerator.isZero }
    var isNegative: Bool { negative }

    func negated() -> Self {
        Self(reduced: numerator, denominator: denominator, negative: !negative && !isZero)
    }

    func adding(_ other: Self) throws -> Self {
        let (lhs, rhs, common) = aligned(with: other)
        if negative == other.negative {
            return try Self(lhs + rhs, common, negative: negative)
        }
        if lhs < rhs {
            return try Self(rhs - lhs, common, negative: other.negative)
        }
        return try Self(lhs - rhs, common, negative: negative)
    }

    func multiplied(by other: Self) throws -> Self {
        try Self(numerator * other.numerator, denominator * other.denominator,
                 negative: negative != other.negative)
    }

    func divided(by other: Self) throws -> Self {
        guard !other.isZero else { throw CalculationError.divisionByZero }
        if denominator == other.denominator {
            return try Self(numerator, other.numerator, negative: negative != other.negative)
        }
        return try Self(numerator * other.denominator, denominator * other.numerator,
                        negative: negative != other.negative)
    }

    func remainder(dividingBy other: Self) throws -> Self {
        guard !other.isZero else { throw CalculationError.divisionByZero }
        let (lhs, rhs, common) = aligned(with: other)
        return try Self(lhs.divided(by: rhs).remainder, common, negative: negative)
    }

    func isLess(than other: Self) -> Bool {
        if negative != other.negative { return negative }
        let (lhs, rhs, _) = aligned(with: other)
        return negative ? rhs < lhs : lhs < rhs
    }

    func rounded(_ rule: FloatingPointRoundingRule) -> Self {
        let (integer, remainder) = numerator.divided(by: denominator)
        let increment: Bool
        switch rule {
        case .up: increment = !negative && !remainder.isZero
        case .down: increment = negative && !remainder.isZero
        default: increment = remainder + remainder >= denominator
        }
        let rounded = increment ? integer + .one : integer
        return Self(reduced: rounded, denominator: .one, negative: negative && !rounded.isZero)
    }

    // Fractional powers are handed to the approximate evaluator.
    func raised(to exponent: Self) throws -> Self? {
        let (integer, remainder) = exponent.numerator.divided(by: exponent.denominator)
        guard remainder.isZero else { return nil }
        if integer.isZero { return .one }
        if isZero {
            guard !exponent.negative else { throw CalculationError.divisionByZero }
            return self
        }
        if numerator == denominator {
            let isOdd = (integer.digits.last ?? 0) % 2 == 1
            return negative && isOdd ? Self.one.negated() : .one
        }
        guard let power = Int(integer.string), power <= 4096 else {
            throw CalculationError.expressionTooComplex
        }
        var base = exponent.negative ? try Self.one.divided(by: self) : self
        var result = Self.one
        var remaining = power
        while remaining > 0 {
            if remaining % 2 == 1 { result = try result.multiplied(by: base) }
            remaining /= 2
            if remaining > 0 { base = try base.multiplied(by: base) }
        }
        return result
    }

    func decimalParts(places: Int) -> (whole: [UInt8], fraction: [UInt8]) {
        let tiny = places > 0 && numerator.shifted(by: places) < denominator
        let leadingZeros = max(0, denominator.digits.count - numerator.digits.count)
        let limit = tiny ? max(places + 1, leadingZeros + 18) : places + 1
        let (whole, remainder) = numerator.divided(by: denominator)
        return (whole.digits, fractionDigits(from: remainder, limit: limit))
    }

    var doubleValue: Double {
        if isZero { return 0 }
        let (whole, remainder) = numerator.divided(by: denominator)
        let limit = max(20, denominator.digits.count - numerator.digits.count + 20)
        let fraction = fractionDigits(from: remainder, limit: limit)
        let unsigned = whole.string + "." + DecimalMagnitude.string(fraction)
        return (negative ? -1 : 1) * (Double(unsigned) ?? .infinity)
    }

    private func fractionDigits(from initialRemainder: DecimalMagnitude, limit: Int) -> [UInt8] {
        var remainder = initialRemainder
        guard !remainder.isZero else { return [] }
        if denominator.isPowerOfTen {
            let leadingZeros = denominator.digits.count - 1 - remainder.digits.count
            let fractionalDigits = Array(repeating: UInt8(0), count: leadingZeros) + remainder.digits
            return Array(fractionalDigits.prefix(limit))
        }
        let multiples = denominator.multiples()
        // Decimal positions before the remainder can reach the divisor are all zeros.
        let leadingZeros = min(limit, max(0, denominator.digits.count - remainder.digits.count - 1))
        var digits = Array(repeating: UInt8(0), count: leadingZeros)
        remainder = remainder.shifted(by: leadingZeros)
        while !remainder.isZero && digits.count < limit {
            let next = remainder.shifted(by: 1).divisionDigit(using: multiples)
            digits.append(next.digit)
            remainder = next.remainder
        }
        return digits
    }

    private func aligned(with other: Self) -> (DecimalMagnitude, DecimalMagnitude, DecimalMagnitude) {
        if denominator == other.denominator { return (numerator, other.numerator, denominator) }
        // Decimal denominators are powers of ten until a nonterminating division is introduced.
        if denominator.isPowerOfTen && other.denominator.isPowerOfTen {
            let delta = denominator.digits.count - other.denominator.digits.count
            return (numerator.shifted(by: max(0, -delta)), other.numerator.shifted(by: max(0, delta)),
                    max(denominator, other.denominator))
        }
        return (numerator * other.denominator, other.numerator * denominator,
                denominator * other.denominator)
    }
}

private struct DecimalMagnitude: Comparable {
    let digits: [UInt8]

    static let zero = Self([0])
    static let one = Self([1])
    var isZero: Bool { digits == [0] }
    var isPowerOfTen: Bool { digits.first == 1 && trailingZeros == digits.count - 1 }
    var trailingZeros: Int { digits.reversed().prefix(while: { $0 == 0 }).count }
    var string: String { Self.string(digits) }

    init(_ digits: [UInt8]) {
        let significant = digits.drop(while: { $0 == 0 })
        self.digits = significant.isEmpty ? [0] : Array(significant)
    }

    static func string(_ digits: [UInt8]) -> String {
        String(decoding: digits.map { $0 + UInt8(ascii: "0") }, as: UTF8.self)
    }

    func shifted(by places: Int) -> Self {
        guard places > 0, !isZero else { return self }
        return Self(digits + Array(repeating: 0, count: places))
    }

    func removingTrailingZeros(_ count: Int) -> Self { Self(Array(digits.dropLast(count))) }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.digits.count != rhs.digits.count { return lhs.digits.count < rhs.digits.count }
        return lhs.digits.lexicographicallyPrecedes(rhs.digits)
    }

    static func + (lhs: Self, rhs: Self) -> Self { combining(lhs, rhs, factor: 1) }
    static func - (lhs: Self, rhs: Self) -> Self { combining(lhs, rhs, factor: -1) }

    private static func combining(_ lhs: Self, _ rhs: Self, factor: Int) -> Self {
        let width = max(lhs.digits.count, rhs.digits.count)
        let lhsDigits = Array(repeating: UInt8(0), count: width - lhs.digits.count) + lhs.digits
        let rhsDigits = Array(repeating: UInt8(0), count: width - rhs.digits.count) + rhs.digits
        var result = lhsDigits
        var carry = 0
        for index in result.indices.reversed() {
            let digit = Int(lhsDigits[index]) + factor * Int(rhsDigits[index]) + carry
            let remainder = (digit + 10) % 10
            result[index] = UInt8(remainder)
            carry = (digit - remainder) / 10
        }
        if carry > 0 { result.insert(UInt8(carry), at: 0) }
        return Self(result)
    }

    static func * (lhs: Self, rhs: Self) -> Self {
        if lhs.isZero || rhs.isZero { return .zero }
        if lhs.isPowerOfTen { return rhs.shifted(by: lhs.digits.count - 1) }
        if rhs.isPowerOfTen { return lhs.shifted(by: rhs.digits.count - 1) }
        var result = Array(repeating: 0, count: lhs.digits.count + rhs.digits.count)
        for (leftIndex, left) in lhs.digits.enumerated() where left != 0 {
            for (rightIndex, right) in rhs.digits.enumerated() {
                result[leftIndex + rightIndex + 1] += Int(left) * Int(right)
            }
        }
        for index in result.indices.dropFirst().reversed() {
            result[index - 1] += result[index] / 10
            result[index] %= 10
        }
        return Self(result.map(UInt8.init))
    }

    func divided(by divisor: Self) -> (quotient: Self, remainder: Self) {
        if self < divisor { return (.zero, self) }
        if divisor.isPowerOfTen {
            let scale = divisor.digits.count - 1
            return (Self(Array(digits.dropLast(scale))), Self(Array(digits.suffix(scale))))
        }
        let multiples = divisor.multiples()
        if digits.count == divisor.digits.count {
            let next = divisionDigit(using: multiples)
            return (Self([next.digit]), next.remainder)
        }
        var quotient: [UInt8] = []
        var remainder = Self.zero
        for digit in digits {
            let next = Self(remainder.digits + [digit]).divisionDigit(using: multiples)
            quotient.append(next.digit)
            remainder = next.remainder
        }
        return (Self(quotient), remainder)
    }

    func commonDivisor(with other: Self) -> Self {
        var lhs = self
        var rhs = other
        while !rhs.isZero && rhs != .one {
            let remainder = lhs.divided(by: rhs).remainder
            lhs = rhs
            rhs = remainder
        }
        return rhs.isZero ? lhs : rhs
    }

    func multiples() -> [Self] {
        var values = [Self.zero]
        for _ in 1...9 { values.append(values.last! + self) }
        return values
    }

    func divisionDigit(using multiples: [Self]) -> (digit: UInt8, remainder: Self) {
        if self < multiples[1] { return (0, self) }
        let digit = multiples.lastIndex { $0 <= self } ?? 0
        return (UInt8(digit), self - multiples[digit])
    }
}
