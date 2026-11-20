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
        (10, 1e-12, "1e-12"),
        (10, 1e20, "1e+20")
    ]

    static let customSeparators: [(ResultFormatting, Double, String)] = [
        (ResultFormatting(places: 2, decimal: .comma, grouping: .period), 12345.875, "12.345,88"),
        (ResultFormatting(places: 2, grouping: .comma), 12345.875, "12,345.88"),
        (ResultFormatting(places: 2, decimal: .comma), 0, "0.0"),
        (ResultFormatting(places: 10, decimal: .comma), 1.23e-12, "1,23e-12"),
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
}
