import XCTest
@testable import termdownCore

/// `Ansi.fit` and `Ansi.fittedHint` — the clamp the TUI chrome was missing.
///
/// `pad` only ever grows, but a dozen call sites composed `left + gap + right`
/// and handed it to `pad` as though it would rein the result in. Autowrap is
/// off, so an over-wide row does not wrap: it clips at the right margin and
/// takes the frame's border with it.
final class FitTests: XCTestCase {

    private func withColor(_ body: () -> Void) {
        let previous = Ansi.colorEnabled
        Ansi.colorEnabled = true
        defer { Ansi.colorEnabled = previous }
        body()
    }

    // MARK: - fit

    func testPadsWhenShort() {
        XCTAssertEqual(Ansi.fit("ab", to: 5), "ab   ")
        XCTAssertEqual(Ansi.width(Ansi.fit("ab", to: 5)), 5)
    }

    func testCutsWhenLong() {
        XCTAssertEqual(Ansi.fit("abcdefgh", to: 5), "abcd\u{2026}")
    }

    func testExactWidthIsUntouched() {
        XCTAssertEqual(Ansi.fit("abcde", to: 5), "abcde")
    }

    /// The invariant the chrome depends on, swept across every interesting size.
    func testResultIsAlwaysExactlyTheTarget() {
        for input in ["", "a", "abc", String(repeating: "x", count: 40), "日本語のテキスト", "a日b語c"] {
            for target in 1...20 {
                XCTAssertEqual(Ansi.width(Ansi.fit(input, to: target)), target,
                               "fit(\"\(input)\", to: \(target))")
            }
        }
    }

    /// A target of zero or less is a degenerate terminal, not a crash.
    func testNonPositiveTargetIsEmpty() {
        XCTAssertEqual(Ansi.fit("abc", to: 0), "")
        XCTAssertEqual(Ansi.fit("abc", to: -3), "")
    }

    /// One column has no room for both content and an ellipsis, so it keeps the
    /// content.
    func testSingleColumnKeepsContentOverTheMarker() {
        XCTAssertEqual(Ansi.fit("abc", to: 1), "a")
    }

    /// `truncate` flattens its input to plain text, which is why the pager lost
    /// every syntax colour at narrow widths. `fit` must not.
    func testStylingSurvivesTheCut() {
        withColor {
            let styled = Ansi.color("abcdefgh", .x256(42))
            let cut = Ansi.fit(styled, to: 5)
            XCTAssertTrue(cut.contains("\u{1B}["), "styling was stripped: \(cut)")
            XCTAssertEqual(Ansi.width(cut), 5)
            XCTAssertEqual(Ansi.strip(cut), "abcd\u{2026}")
        }
    }

    /// A wide glyph cannot be drawn half-width, so a cut through one stands in
    /// spaces rather than leaving the row a column short.
    func testAWideGlyphStraddlingTheCut() {
        XCTAssertEqual(Ansi.width(Ansi.fit("ab語cd", to: 4)), 4)
        XCTAssertEqual(Ansi.width(Ansi.fit("語語語", to: 3)), 3)
    }

    // MARK: - fittedHint

    private let hints = ["/ search", "↑↓ move", "↵ open", "? help"]
    private let sep = "  ·  "

    func testKeepsEveryHintWhenThereIsRoom() {
        XCTAssertEqual(Ansi.fittedHint(hints, separator: sep, width: 100),
                       hints.joined(separator: sep))
    }

    /// Trailing hints go first, so what survives is the most useful.
    func testDropsFromTheEnd() {
        let fitted = Ansi.fittedHint(hints, separator: sep, width: 30)
        XCTAssertTrue(fitted.contains("/ search"), fitted)
        XCTAssertFalse(fitted.contains("? help"), fitted)
        XCTAssertLessThanOrEqual(Ansi.width(fitted), 30)
    }

    /// The point of dropping rather than cutting: never a stub like `? he…`.
    func testNeverProducesATruncatedStub() {
        for width in 0...60 {
            let fitted = Ansi.fittedHint(hints, separator: sep, width: width)
            XCTAssertLessThanOrEqual(Ansi.width(fitted), width, "width \(width)")
            XCTAssertFalse(fitted.contains("\u{2026}"), "cut a hint at width \(width): \(fitted)")
            // Whatever survives is a whole hint, joined by whole separators.
            if !fitted.isEmpty {
                for segment in fitted.components(separatedBy: sep) {
                    XCTAssertTrue(hints.contains(segment), "partial hint '\(segment)' at width \(width)")
                }
            }
        }
    }

    /// Not even one hint fits: better nothing than a fragment.
    func testTooNarrowForAnyHintIsEmpty() {
        XCTAssertEqual(Ansi.fittedHint(hints, separator: sep, width: 3), "")
        XCTAssertEqual(Ansi.fittedHint(hints, separator: sep, width: 0), "")
    }

    func testEmptyInput() {
        XCTAssertEqual(Ansi.fittedHint([], separator: sep, width: 40), "")
    }
}
