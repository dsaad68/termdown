import XCTest
@testable import termdownCore

final class EmojiTests: XCTestCase {

    func testSubstitutesKnownShortcodes() {
        XCTAssertEqual(Emoji.substitute("ship it :rocket:"), "ship it 🚀")
        XCTAssertEqual(Emoji.substitute(":tada: release"), "🎉 release")
        XCTAssertEqual(Emoji.substitute("LGTM :+1:"), "LGTM 👍")
        XCTAssertEqual(Emoji.substitute("nope :-1:"), "nope 👎")
    }

    func testLeavesUnknownAndPartialTokensLiteral() {
        XCTAssertEqual(Emoji.substitute(":not_a_real_emoji:"), ":not_a_real_emoji:")
        XCTAssertEqual(Emoji.substitute("ratio 16:9 and time 12:34"), "ratio 16:9 and time 12:34")
        XCTAssertEqual(Emoji.substitute("a smiley :) stays"), "a smiley :) stays")
        XCTAssertEqual(Emoji.substitute("https://example.com"), "https://example.com")
    }

    func testNoColonIsFastPathUnchanged() {
        XCTAssertEqual(Emoji.substitute("plain text with no codes"), "plain text with no codes")
    }

    func testMultipleAndAdjacent() {
        XCTAssertEqual(Emoji.substitute(":fire::fire:"), "🔥🔥")
        XCTAssertEqual(Emoji.substitute("a :star: b :heart: c"), "a ⭐ b ❤️ c")
    }

    func testEmojiRendersInDocumentProseButNotCode() {
        let doc = AnsiRenderer(width: 80, theme: .mono).render("Done :rocket: and `:rocket:` literal")
        let text = doc.lines.joined(separator: "\n")
        XCTAssertTrue(text.contains("🚀"), text)              // prose shortcode converted
        XCTAssertTrue(text.contains(":rocket:"), text)        // code span left literal
    }
}
