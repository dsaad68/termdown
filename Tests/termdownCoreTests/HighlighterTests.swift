import XCTest
@testable import termdownCore

final class HighlighterTests: XCTestCase {

    func testEmptyCodeReturnsEmpty() {
        XCTAssertEqual(Highlighter.colorMap("", language: "swift", theme: .dark), [])
    }

    func testColorMapHasOneEntryPerCharacter() {
        let code = "let x = 1"
        XCTAssertEqual(Highlighter.colorMap(code, language: "swift", theme: .dark).count, code.count)
    }

    func testMultibyteAlignment() {
        // The UTF-16 → Character collapse must keep one colour per Character even
        // with wide / multibyte content (no over/under-run).
        let code = "let 日 = 1"
        XCTAssertEqual(Highlighter.colorMap(code, language: "swift", theme: .dark).count, code.count)
    }

    func testUnknownLanguageIsAllCodeText() {
        let code = "let x = 1"
        let colors = Highlighter.colorMap(code, language: "no-such-lang", theme: .dark)
        XCTAssertTrue(colors.allSatisfy { $0 == Theme.dark.codeText })
    }

    func testNilLanguageIsAllCodeText() {
        let code = "anything here"
        let colors = Highlighter.colorMap(code, language: nil, theme: .dark)
        XCTAssertTrue(colors.allSatisfy { $0 == Theme.dark.codeText })
    }

    func testKnownLanguageColoursSomething() {
        // A Swift keyword should pull at least one character off the plain colour.
        let colors = Highlighter.colorMap("let x = 1", language: "swift", theme: .dark)
        XCTAssertTrue(colors.contains { $0 != Theme.dark.codeText },
                      "expected some highlighted tokens for swift")
    }

    func testShellCommandIsColouredAsLink() {
        // applyShellCommands paints the leading command word with theme.link.
        let code = "swift test"
        let colors = Highlighter.colorMap(code, language: "bash", theme: .dark)
        XCTAssertEqual(colors.count, code.count)
        // The command word "swift" (first 5 chars) should be link-coloured.
        XCTAssertTrue(colors.prefix(5).contains(Theme.dark.link),
                      "expected the shell command word to be link-coloured")
    }
}
