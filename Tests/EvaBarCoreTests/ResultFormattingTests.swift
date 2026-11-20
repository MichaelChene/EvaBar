import EvaBarCore
import Testing

struct ResultFormattingTests {
    static let results: [(Int, Double, String)] = [
        (10, 0.1 + 0.2, "0.3"),
        (10, 0, "0.0"),
        (0, -0.0, "0.0"),
        (2, -1.125, "-1.13"),
        (2, 24000, "24000"),
        (0, -0.4, "0"),
        (0, 1.5, "2"),
        (10, 1e-12, "0.000000000001"),
        (10, 1e20, "100000000000000000000"),
        (10, 1.0000000000000002e20, "100000000000000020000"),
        (10, Double.leastNonzeroMagnitude, "0." + String(repeating: "0", count: 323) + "5"),
        (10, Double.greatestFiniteMagnitude, "17976931348623157" + String(repeating: "0", count: 292))
    ]

    static let customSeparators: [(ResultFormatting, Double, String)] = [
        (ResultFormatting(places: 2, decimal: .comma, grouping: .period), 12345.875, "12.345,88"),
        (ResultFormatting(places: 2, grouping: .comma), 12345.875, "12,345.88"),
        (ResultFormatting(places: 2, decimal: .comma), 0, "0.0"),
        (ResultFormatting(places: 10, decimal: .comma), -1.23e-12, "-0,00000000000123"),
        (ResultFormatting(places: 2, grouping: .comma), 1e20, "100,000,000,000,000,000,000"),
        (ResultFormatting(places: 2, decimal: .comma, grouping: .comma), 12345.875, "12345,88")
    ]

    @Test(arguments: results)
    func formatsResult(_ testCase: (places: Int, value: Double, expected: String)) {
        let formatter = ResultFormatting(places: testCase.places)
        #expect(formatter.string(testCase.value) == testCase.expected)
    }

    @Test(arguments: customSeparators)
    func formatsResultWithCustomSeparators(_ testCase: (formatter: ResultFormatting, value: Double, expected: String)) {
        #expect(testCase.formatter.string(testCase.value) == testCase.expected)
    }

    @Test func formatsDecimalLiteralWithoutLosingDigits() throws {
        let source = "12131231232123212321123.12312311231232"
        #expect(try ResultFormatting(places: 15).string(forExpression: source) == source)
        #expect(try ResultFormatting(places: 10).string(forExpression: source) == "12131231232123212321123.1231231123")
        #expect(try ResultFormatting(places: 2, decimal: .comma, grouping: .period)
            .string(forExpression: "-999999999999999999999.995") == "-1.000.000.000.000.000.000.000")
        #expect(try ResultFormatting(places: 2).string(forExpression: "sqrt(144) + 3") == "15")
    }

    @Test func addsAndSubtractsLongDecimalLiteralsBeforeRounding() throws {
        let source = "234234444441231231231231244444.12323231444444443234323432 + 1231232.21231231232123"
        #expect(try ResultFormatting(places: 15).string(forExpression: source)
            == "234234444441231231231232475676.335544626765674")
        #expect(try ResultFormatting(places: 10).string(forExpression: source)
            == "234234444441231231231232475676.3355446268")
        #expect(try ResultFormatting(places: 2).string(forExpression: "999999999999999999999.01 - 1000000000000000000000.02") == "-1.01")
        #expect(try ResultFormatting(places: 2).string(forExpression: ".014 + .004") == "0.02")
        #expect(try ResultFormatting(places: 2).string(forExpression: "2 - -3 + .5") == "5.5")
    }

    @Test func reportsPendingOperandAfterLongDecimalSum() throws {
        let format = ResultFormatting(places: 15)
        let source = "23423444444123123123444.12323231444444443234323432 + 1299999.21231231232123"
        #expect(try format.string(forExpression: source) == "23423444444123124423443.335544626765674")
        #expect(throws: CalculationError.expectedValue) {
            try format.string(forExpression: source + " +")
        }
    }

    @Test(arguments: [
        ("(9007199254740993 + 1) - 9007199254740993", "1"),
        ("9007199254740993 * 3", "27021597764222979"),
        ("12345678901234567890.123456789012345 * 1.01", "12469135690246913569.024691356902468"),
        ("100000000000000000001 / 10", "10000000000000000000.1"),
        ("1 / 3", "0.333333333333333"),
        ("(1 / 3) * 3", "1"),
        ("9007199254740993 % 2", "1"),
        ("mod(-9007199254740993, 2)", "-1"),
        ("9007199254740993 ^ 2", "81129638414606699710187514626049"),
        ("pow(2, -3)", "0.125"),
        ("1e25 + 1 - 1e25", "1"),
        ("1.0000000000000001e25", "10000000000000001000000000"),
        ("min(9007199254740993,9007199254740995)", "9007199254740993"),
        ("avg(9007199254740993,9007199254740995)", "9007199254740994"),
        ("round(-9007199254740993.5)", "-9007199254740994"),
        ("1e308 + 1e308 - 1e308", "1" + String(repeating: "0", count: 308)),
        ("(123123.23123123213 + 87878678678 + 1.2232)", "87878801802.45443123213"),
    ])
    func formatsExactArithmetic(_ testCase: (String, String)) throws {
        #expect(try ResultFormatting(places: 15).string(forExpression: testCase.0) == testCase.1)
    }

    @Test func reportsUnclosedParenthesisWhileEditingLongResult() {
        #expect(throws: CalculationError.expectedClosingParenthesis) {
            try ResultFormatting(places: 15).string(forExpression: "(123123.23123123213 + 87878678678 + 1.2232")
        }
    }

    @Test func reducesFractionsBeforeEnforcingDigitBound() throws {
        let format = ResultFormatting(places: 15)
        #expect(try format.string(forExpression: "((1 / 3) * 3)^4096") == "1")
        #expect(try format.string(forExpression: "((3 / 7) * (7 / 3))^4096") == "1")
        #expect(try format.string(forExpression: "((25 / 75)^600) * (3^600)") == "1")
        #expect(throws: CalculationError.expressionTooComplex) {
            try format.string(forExpression: "10^1024")
        }
    }

    @Test func handlesZeroAndUnitPowersWithVeryLargeExponents() throws {
        let format = ResultFormatting(places: 15)
        #expect(try format.string(forExpression: "-0e999999999999999999999999999") == "0.0")
        #expect(try format.string(forExpression: "(-1)^9007199254740993") == "-1")
        #expect(try format.string(forExpression: "(-1)^-9007199254740994") == "1")
        #expect(try format.string(forExpression: "1^9007199254740993") == "1")
        #expect(try format.string(forExpression: "0^9007199254740993") == "0.0")
        #expect(throws: CalculationError.divisionByZero) {
            try format.string(forExpression: "0^-9007199254740993")
        }
    }

    @Test func formatsTinyQuotientsInPlainDecimal() throws {
        let format = ResultFormatting(places: 15, decimal: .comma)
        let repeating = "-0," + String(repeating: "0", count: 400) + String(repeating: "3", count: 18)
        let terminating = "0," + String(repeating: "0", count: 402) + "4"
        #expect(try format.string(forExpression: "-1e-400 / 3") == repeating)
        #expect(try format.string(forExpression: "1e-400 / 250") == terminating)
    }
}
