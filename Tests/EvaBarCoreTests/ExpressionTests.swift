import EvaBarCore
import Testing

struct ExpressionTests {
    static let expressions: [(String, Double)] = [
        ("2 + 3 * 4", 14),
        ("(2 + 3) * 4", 20),
        ("2^3^2", 512),
        ("-2^2", -4),
        ("(-2)^2", 4),
        ("2^-3", 0.125),
        ("10 - -2", 12),
        ("2x3 + 4×2 − 8÷4", 12),
        ("17 % 5", 2),
        ("-17 % 5", -2),
        ("mod(17, -5)", 2),
        ("MAX(3, min(8, 2), AVG(2, 4, 6))", 4),
        ("avg(1e308, 1e308)", 1e308),
        ("avg(1.7976931348623157e308, 1.7976931348623157e308, 1.7976931348623157e308)", .greatestFiniteMagnitude),
        ("avg(5e-324, 5e-324)", .leastNonzeroMagnitude),
        ("sqrt(81) + pow(2, 3) + abs(-6)", 23),
        ("floor(-2.1) + ceil(2.1) + round(-2.5)", -3),
        ("log(81, 3) + ln(1)", 4),
        ("sin(pi/2) + cos(0) + tan(0)", 2),
        ("arcsin(1) + arccos(0) + arctan(0)", .pi),
        ("atan2(1, -1)", 3 * .pi / 4),
        ("asin(1)", .pi / 2),
        ("acos(-1)", .pi),
        ("atan(1)", .pi / 4),
        ("π + PI", 2 * .pi),
        (" .5 + 2. + 2E−1 ", 2.7)
    ]

    static let invalidExpressions: [(String, CalculationError)] = [
        ("", .expectedValue),
        ("(1+2", .expectedClosingParenthesis),
        ("2 3", .unexpectedInput),
        ("1.2.3", .unexpectedInput),
        ("mystery(1)", .unknownName),
        ("2e-", .invalidNumber),
        ("avg()", .wrongArgumentCount),
        ("log(2)", .wrongArgumentCount),
        ("sqrt(1,2)", .wrongArgumentCount),
        ("max(1,)", .expectedValue),
        ("1/0", .divisionByZero),
        ("mod(3, -0)", .divisionByZero),
        ("sqrt(-1)", .outsideDomain),
        ("arcsin(2)", .outsideDomain),
        ("acos(2)", .outsideDomain),
        ("atan(1, 2)", .wrongArgumentCount),
        ("log(2, 1)", .outsideDomain),
        ("ln(0)", .outsideDomain),
        ("1e308 * 2", .overflow),
        ("1e1000", .overflow),
        (String(repeating: "(", count: 130) + "1", .expressionTooComplex),
        (String(repeating: "^2", count: 2050), .expressionTooComplex)
    ]

    @Test(arguments: expressions)
    func evaluatesExpression(_ testCase: (source: String, expected: Double)) throws {
        let actual = try Expression.evaluate(testCase.source)
        #expect(abs(actual - testCase.expected) <= abs(testCase.expected) * 1e-14)
    }

    @Test(arguments: invalidExpressions)
    func reportsCalculationError(_ testCase: (source: String, expected: CalculationError)) {
        #expect(throws: testCase.expected) {
            try Expression.evaluate(testCase.source)
        }
    }
}
