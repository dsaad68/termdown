import XCTest
@testable import termdownCore

final class MathConverterTests: XCTestCase {

    // MARK: - latexToUnicode

    func testGreekLetters() {
        XCTAssertEqual(MathConverter.latexToUnicode("\\alpha"), "α")
        XCTAssertEqual(MathConverter.latexToUnicode("\\beta + \\gamma"), "β + γ")
        XCTAssertEqual(MathConverter.latexToUnicode("\\Omega"), "Ω")
        XCTAssertEqual(MathConverter.latexToUnicode("\\pi"), "π")
    }

    func testOperatorsAndRelations() {
        XCTAssertEqual(MathConverter.latexToUnicode("a \\leq b"), "a ≤ b")
        XCTAssertEqual(MathConverter.latexToUnicode("x \\neq y"), "x ≠ y")
        XCTAssertEqual(MathConverter.latexToUnicode("a \\times b"), "a × b")
        XCTAssertEqual(MathConverter.latexToUnicode("\\forall x \\in S"), "∀ x ∈ S")
        XCTAssertEqual(MathConverter.latexToUnicode("\\sum"), "∑")
        XCTAssertEqual(MathConverter.latexToUnicode("\\infty"), "∞")
        XCTAssertEqual(MathConverter.latexToUnicode("a \\to b"), "a → b")
    }

    func testSuperscripts() {
        XCTAssertEqual(MathConverter.latexToUnicode("x^2"), "x²")
        XCTAssertEqual(MathConverter.latexToUnicode("x^{10}"), "x¹⁰")
        XCTAssertEqual(MathConverter.latexToUnicode("E = mc^2"), "E = mc²")
        // Characters without a superscript form fall back to ^(...).
        XCTAssertEqual(MathConverter.latexToUnicode("e^{i\\pi}"), "e^(iπ)")
    }

    func testSubscripts() {
        XCTAssertEqual(MathConverter.latexToUnicode("x_1"), "x₁")
        XCTAssertEqual(MathConverter.latexToUnicode("H_2O"), "H₂O")
        XCTAssertEqual(MathConverter.latexToUnicode("a_{ij}"), "aᵢⱼ")
    }

    func testFraction() {
        XCTAssertEqual(MathConverter.latexToUnicode("\\frac{1}{2}"), "1/2")
        XCTAssertEqual(MathConverter.latexToUnicode("\\frac{a+b}{c}"), "(a+b)/c")
    }

    func testSqrt() {
        XCTAssertEqual(MathConverter.latexToUnicode("\\sqrt{2}"), "√2")
        XCTAssertEqual(MathConverter.latexToUnicode("\\sqrt{x+1}"), "√(x+1)")
    }

    func testBlackboardAndAccents() {
        XCTAssertEqual(MathConverter.latexToUnicode("\\mathbb{R}"), "ℝ")
        XCTAssertEqual(MathConverter.latexToUnicode("\\hat{H}"), "Ĥ")
    }

    func testTextWrapperAndUnknownCommand() {
        XCTAssertEqual(MathConverter.latexToUnicode("\\text{if } x > 0"), "if  x > 0")
        // Unknown commands degrade to their bare name rather than vanishing.
        XCTAssertEqual(MathConverter.latexToUnicode("\\foobar"), "foobar")
    }

    // MARK: - split

    func testSplitInlineMath() {
        let parts = MathConverter.split("value $x^2$ here")
        XCTAssertEqual(parts.count, 3)
        XCTAssertFalse(parts[0].isMath)
        XCTAssertTrue(parts[1].isMath)
        XCTAssertEqual(parts[1].text, "x^2")
        XCTAssertFalse(parts[2].isMath)
    }

    func testSplitDisplayMath() {
        let parts = MathConverter.split("$$a+b$$")
        XCTAssertEqual(parts.count, 1)
        XCTAssertTrue(parts[0].isMath)
        XCTAssertEqual(parts[0].text, "a+b")
    }

    func testSplitIsCurrencySafe() {
        // "$5" / "$10" must not be treated as a math span.
        let parts = MathConverter.split("it costs $5 and then $10 total")
        XCTAssertEqual(parts.count, 1)
        XCTAssertFalse(parts[0].isMath)
    }

    func testSplitUnclosedDollarIsPlain() {
        let parts = MathConverter.split("a lone $ sign and $x without close")
        XCTAssertTrue(parts.allSatisfy { !$0.isMath })
    }

    func testSplitNoDollar() {
        let parts = MathConverter.split("plain text")
        XCTAssertEqual(parts.count, 1)
        XCTAssertFalse(parts[0].isMath)
        XCTAssertEqual(parts[0].text, "plain text")
    }
}
