import EvaBarCore

extension CalculationError {
    var isEditingError: Bool {
        switch self {
        case .expectedValue, .expectedClosingParenthesis, .unexpectedInput, .unknownName,
             .invalidNumber, .wrongArgumentCount:
            true
        case .divisionByZero, .outsideDomain, .overflow, .expressionTooComplex:
            false
        }
    }

    @MainActor
    var messages: (summary: String, detail: String) {
        switch self {
        case .expectedValue: (L10n.text("Expected value"), L10n.text("Expected a number or function"))
        case .expectedClosingParenthesis: (L10n.text("Missing “)”"), L10n.text("Missing closing parenthesis"))
        case .unexpectedInput: (L10n.text("Unexpected input"), L10n.text("Unexpected input after the expression"))
        case .unknownName: (L10n.text("Unknown name"), L10n.text("Unknown function or constant"))
        case .invalidNumber: (L10n.text("Invalid number"), L10n.text("Check the format of the number in the expression."))
        case .wrongArgumentCount: (L10n.text("Wrong arg count"), L10n.text("Wrong number of arguments"))
        case .divisionByZero: (L10n.text("Division by zero"), L10n.text("The divisor must be nonzero."))
        case .outsideDomain: (L10n.text("Out of domain"), L10n.text("Outside the function’s domain"))
        case .overflow: (L10n.text("Result too large"), L10n.text("The result exceeds the supported range."))
        case .expressionTooComplex: (L10n.text("Too complex"), L10n.text("Expression is too complex"))
        }
    }
}
