import Foundation

public enum CalculationError: Error, Equatable {
    case expectedValue
    case expectedClosingParenthesis
    case unexpectedInput
    case unknownName
    case invalidNumber
    case wrongArgumentCount
    case divisionByZero
    case outsideDomain
    case overflow
    case expressionTooComplex
}

public enum Expression {
    private static let inputLimit = 4096

    public static func evaluate(_ source: String) throws -> Double {
        let characters = Array(source.lowercased().prefix(inputLimit + 1))
        guard characters.count <= inputLimit else { throw CalculationError.expressionTooComplex }

        var parser = Parser(characters: characters)
        let result = try parser.sum(depth: 0)
        guard parser.peek() == nil else { throw CalculationError.unexpectedInput }
        return result
    }

    private struct Parser {
        let characters: [Character]
        var index = 0

        mutating func peek() -> Character? {
            while index < characters.count && characters[index].isWhitespace {
                index += 1
            }
            return index < characters.count ? characters[index] : nil
        }

        mutating func take(_ character: Character) -> Bool {
            guard peek() == character else { return false }
            index += 1
            return true
        }

        mutating func sum(depth: Int) throws -> Double {
            var value = try product(depth: depth)
            while let operatorCharacter = peek(), ["+", "-", "−"].contains(operatorCharacter) {
                index += 1
                let right = try product(depth: depth)
                value = try Self.finite(operatorCharacter == "+" ? value + right : value - right)
            }
            return value
        }

        mutating func product(depth: Int) throws -> Double {
            var value = try signedPower(depth: depth)
            while let operatorCharacter = peek(), ["*", "×", "x", "/", "÷", "%"].contains(operatorCharacter) {
                index += 1
                let right = try signedPower(depth: depth)
                switch operatorCharacter {
                case "/", "÷":
                    guard right != 0 else { throw CalculationError.divisionByZero }
                    value = try Self.finite(value / right)
                case "%":
                    value = try Self.remainder(value, right)
                default:
                    value = try Self.finite(value * right)
                }
            }
            return value
        }

        mutating func signedPower(depth: Int) throws -> Double {
            guard depth < 128 else { throw CalculationError.expressionTooComplex }
            if take("+") { return try signedPower(depth: depth + 1) }
            if take("-") || take("−") { return try -signedPower(depth: depth + 1) }

            let base = try atom(depth: depth)
            guard take("^") else { return base }
            return try Self.finite(pow(base, signedPower(depth: depth + 1)))
        }

        mutating func atom(depth: Int) throws -> Double {
            if take("(") {
                let value = try sum(depth: depth + 1)
                guard take(")") else { throw CalculationError.expectedClosingParenthesis }
                return value
            }
            if take("π") { return .pi }
            guard let first = peek() else { throw CalculationError.expectedValue }
            if first.isASCIIDigit || first == "." { return try number() }
            guard first.isASCIILetter else { throw CalculationError.expectedValue }

            let start = index
            while index < characters.count,
                  characters[index].isASCIILetter || characters[index].isASCIIDigit {
                index += 1
            }
            let name = String(characters[start..<index])
            if name == "pi" { return .pi }
            guard take("(") else { throw CalculationError.unknownName }

            var arguments: [Double] = []
            if !take(")") {
                repeat {
                    arguments.append(try sum(depth: depth + 1))
                } while take(",")
                guard take(")") else { throw CalculationError.expectedClosingParenthesis }
            }
            return try Self.call(name, arguments)
        }

        mutating func number() throws -> Double {
            let start = index
            scanDigits()
            if index < characters.count && characters[index] == "." {
                index += 1
                scanDigits()
            }
            if index < characters.count && characters[index] == "e" {
                index += 1
                if index < characters.count && ["+", "-", "−"].contains(characters[index]) {
                    index += 1
                }
                let exponentStart = index
                scanDigits()
                guard index > exponentStart else { throw CalculationError.invalidNumber }
            }

            let literal = String(characters[start..<index]).replacingOccurrences(of: "−", with: "-")
            guard let value = Double(literal) else { throw CalculationError.invalidNumber }
            return try Self.finite(value)
        }

        mutating func scanDigits() {
            while index < characters.count && characters[index].isASCIIDigit {
                index += 1
            }
        }

        static func finite(_ value: Double) throws -> Double {
            if value.isNaN { throw CalculationError.outsideDomain }
            guard value.isFinite else { throw CalculationError.overflow }
            return value
        }

        static func remainder(_ value: Double, _ divisor: Double) throws -> Double {
            guard divisor != 0 else { throw CalculationError.divisionByZero }
            return value.truncatingRemainder(dividingBy: divisor)
        }

        static func call(_ name: String, _ arguments: [Double]) throws -> Double {
            switch name {
            case "min", "max", "avg":
                guard let first = arguments.first else { throw CalculationError.wrongArgumentCount }
                if name == "min" { return arguments.dropFirst().reduce(first, min) }
                if name == "max" { return arguments.dropFirst().reduce(first, max) }
                let scale = arguments.reduce(0) { max($0, abs($1)) }
                guard scale > 0 else { return 0 }
                let scaledSum = arguments.reduce(0) { $0 + $1 / scale }
                return scaledSum / Double(arguments.count) * scale

            case "pow", "mod", "log", "atan2":
                guard arguments.count == 2 else { throw CalculationError.wrongArgumentCount }
                let x = arguments[0]
                let y = arguments[1]
                switch name {
                case "pow": return try finite(pow(x, y))
                case "mod": return try remainder(x, y)
                case "log":
                    guard x > 0 && y > 0 && y != 1 else { throw CalculationError.outsideDomain }
                    return try finite(log(x) / log(y))
                default: return atan2(x, y)
                }

            case "sqrt", "abs", "floor", "ceil", "round", "ln", "sin", "cos", "tan",
                 "arcsin", "asin", "arccos", "acos", "arctan", "atan":
                guard arguments.count == 1 else { throw CalculationError.wrongArgumentCount }
                let x = arguments[0]
                switch name {
                case "sqrt": return try finite(sqrt(x))
                case "abs": return abs(x)
                case "floor": return floor(x)
                case "ceil": return ceil(x)
                case "round": return x.rounded()
                case "ln":
                    guard x > 0 else { throw CalculationError.outsideDomain }
                    return log(x)
                case "sin": return sin(x)
                case "cos": return cos(x)
                case "tan": return tan(x)
                case "arcsin", "asin": return try finite(asin(x))
                case "arccos", "acos": return try finite(acos(x))
                default: return atan(x)
                }

            default:
                throw CalculationError.unknownName
            }
        }
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
    var isASCIILetter: Bool { ("a"..."z").contains(self) }
}
