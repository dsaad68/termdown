import XCTest
@testable import MermaidRenderer
@testable import termdown
@testable import termdownCore

/// Tests for the shared render context: theme resolution and the guarantee that
/// every render — file, string, or live re-render after an edit — is built with
/// the same settings.
final class RenderContextTests: XCTestCase {

    private func context(theme: String? = nil,
                         mermaid: Bool = true,
                         charset: MermaidCharset = .unicode) -> RenderContext {
        RenderContext(themeName: theme, mermaidEnabled: mermaid, mermaidCharset: charset)
    }

    // MARK: - Theme resolution

    func testNoThemeNameIsDark() {
        let ctx = context()
        XCTAssertEqual(ctx.themeName, "dark")
    }

    /// A typo in a config file must not stop the app from starting, and the name
    /// it reports has to match the theme actually in use — otherwise the theme
    /// picker opens on a row that isn't the active one.
    func testUnknownThemeFallsBackToDarkAndReportsDark() {
        let ctx = context(theme: "no-such-theme")
        XCTAssertEqual(ctx.themeName, "dark")
        // Themes aren't Equatable, so compare what they paint.
        let sample = "# H\n\n`code` and [link](x)\n"
        XCTAssertEqual(ctx.render(sample, width: 40).lines,
                       context(theme: "dark").render(sample, width: 40).lines,
                       "an unknown name must render as dark, not as nothing")
    }

    func testKnownThemeIsKeptInCanonicalLowercase() {
        XCTAssertEqual(context(theme: "nord").themeName, "nord")
        XCTAssertEqual(context(theme: "NORD").themeName, "nord")
        XCTAssertEqual(context(theme: "Rose-Pine").themeName, "rose-pine")
    }

    /// Previewing swaps the live theme without claiming it as the saved one, so
    /// leaving the selector without pressing Enter doesn't persist a choice.
    func testPreviewChangesTheThemeButNotTheSavedName() {
        let ctx = context(theme: "dark")
        ctx.previewTheme("nord")
        XCTAssertEqual(ctx.themeName, "dark", "preview must not rename the saved theme")
        XCTAssertNotEqual(ctx.render("# H", width: 40).lines,
                          context(theme: "dark").render("# H", width: 40).lines,
                          "the preview should be visible in the output")
    }

    // MARK: - Every render carries every setting

    /// The regression this type exists to prevent: the in-memory edit re-render
    /// used to build its own `AnsiRenderer` and drop the mermaid options, so an
    /// unsaved edit drew diagrams that `mermaid: false` had switched off.
    func testMermaidDisabledAppliesToRenderAndRenderFile() throws {
        let doc = "```mermaid\ngraph LR\nA --> B\n```\n"
        let url = try tempFile(doc)
        defer { try? FileManager.default.removeItem(at: url) }

        let off = context(mermaid: false)
        XCTAssertTrue(text(off.render(doc, width: 60)).contains("graph LR"),
                      "with mermaid off the source shows as a code block")
        XCTAssertTrue(text(try XCTUnwrap(off.renderFile(url, width: 60))).contains("graph LR"),
                      "renderFile must honor the same setting as render")

        let on = context(mermaid: true)
        XCTAssertFalse(text(on.render(doc, width: 60)).contains("graph LR"),
                       "with mermaid on the source is replaced by a diagram")
    }

    func testMermaidCharsetAppliesToEveryRender() {
        let doc = "```mermaid\ngraph LR\nA --> B\n```\n"
        XCTAssertTrue(text(context(charset: .ascii).render(doc, width: 60)).contains("+---+"),
                      "ascii charset should draw ascii nodes")
        XCTAssertTrue(text(context(charset: .unicode).render(doc, width: 60)).contains("\u{25BA}"),
                      "unicode charset should draw a unicode arrowhead")
    }

    /// `B` toggles banners from inside an escaping pager callback; the very next
    /// render has to see it — which is why this is a class and not a struct.
    func testBannerToggleIsVisibleToTheNextRender() {
        let ctx = context()
        let plain = heading(ctx.render("# Title", width: 40))
        ctx.headingBanners = true
        let banner = heading(ctx.render("# Title", width: 40))
        XCTAssertFalse(plain.contains("48;5;") || plain.contains("48;2;"), plain)
        XCTAssertTrue(banner.contains("48;5;") || banner.contains("48;2;"), banner)
    }

    // MARK: - renderFile

    func testRenderFileReadsTheFile() throws {
        let url = try tempFile("# From disk\n")
        defer { try? FileManager.default.removeItem(at: url) }
        let doc = try XCTUnwrap(context().renderFile(url, width: 40))
        XCTAssertEqual(doc.headings.first?.text, "From disk")
    }

    /// nil rather than a crash: the file can be deleted between the picker
    /// listing it and the pager opening it.
    func testRenderFileReturnsNilForAMissingFile() {
        let gone = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).md")
        XCTAssertNil(context().renderFile(gone, width: 40))
    }

    // MARK: - Helpers

    private func tempFile(_ contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("td-ctx-\(UUID().uuidString).md")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func text(_ doc: RenderedDocument) -> String {
        doc.lines.map { Ansi.strip($0) }.joined(separator: "\n")
    }

    private func heading(_ doc: RenderedDocument) -> String {
        doc.lines.first { Ansi.strip($0).contains("Title") } ?? ""
    }
}
