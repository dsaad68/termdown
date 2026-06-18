import XCTest
@testable import termdownCore

/// Edge cases for the LaTeX→Unicode converter: nesting, unmatched braces, mixed
/// scripts, empty scripts, and currency/newline safety.
final class MathConverterEdgeTests: XCTestCase {

    func testNestedFraction() {
        XCTAssertEqual(MathConverter.latexToUnicode("\\frac{\\frac{a}{b}}{c}"), "(a/b)/c")
    }

    func testBothScriptsOnBase() {
        XCTAssertEqual(MathConverter.latexToUnicode("x^2_3"), "x²₃")
    }

    func testEmptyBracedScriptFallsBack() {
        // No script form for an empty arg → literal caret + parens (degrades, no crash).
        XCTAssertEqual(MathConverter.latexToUnicode("x^{}"), "x^()")
    }

    func testUnmatchedBraceDoesNotCrash() {
        // An unclosed wrapper must not trap; it degrades to readable text.
        let out = MathConverter.latexToUnicode("\\text{unclosed")
        XCTAssertTrue(out.contains("unclosed"), out)
    }

    func testUnknownCommandFallsBackToName() {
        XCTAssertEqual(MathConverter.latexToUnicode("\\foobar"), "foobar")
    }

    func testNestedTextWrapper() {
        // \mathbf inside \text: both wrappers expand to their argument.
        let out = MathConverter.latexToUnicode("\\text{a \\mathbf{b} c}")
        XCTAssertEqual(out, "a b c")
    }

    func testCurrencyAcrossNewlineIsNotMath() {
        // Inline math may not span a newline, so this stays two plain segments.
        let segs = MathConverter.split("cost $x\nmore $y")
        XCTAssertTrue(segs.allSatisfy { !$0.isMath }, "no segment should be math")
    }

    func testDeepNestingTerminates() {
        // More fraction nesting than the pass limit must still return (no hang).
        let deep = "\\frac{\\frac{\\frac{\\frac{a}{b}}{c}}{d}}{e}"
        let out = MathConverter.latexToUnicode(deep)
        XCTAssertFalse(out.isEmpty)
    }
}
