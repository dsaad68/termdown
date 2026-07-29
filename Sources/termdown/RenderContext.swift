import Foundation
import MermaidRenderer
import termdownCore

/// The theme, banner mode and mermaid settings that every render reads, plus
/// the renderers themselves.
///
/// A class rather than a struct: the viewer's theme selector (`p`) and banner
/// toggle (`B`) mutate this from inside escaping pager callbacks, and the render
/// closures have to see the new value on the very next call. As top-level `var`s
/// in `main.swift` that worked by accident of global scope — it stops working
/// the moment the state is handed to a type, which is what opening a single file
/// directly requires.
final class RenderContext {
    private(set) var theme: Theme
    private(set) var themeName: String
    var headingBanners = false
    let mermaidEnabled: Bool
    let mermaidCharset: MermaidCharset

    init(themeName: String?, mermaidEnabled: Bool, mermaidCharset: MermaidCharset) {
        theme = RenderContext.theme(named: themeName)
        // Keep the *canonical* spelling of a name that resolves, so the theme
        // picker opens on the right row; anything else reports as `dark`,
        // matching the theme actually in use.
        self.themeName = themeName.flatMap { Theme.named($0) != nil ? $0.lowercased() : nil } ?? "dark"
        self.mermaidEnabled = mermaidEnabled
        self.mermaidCharset = mermaidCharset
    }

    /// An unknown name falls back to `dark`: a typo in a config file should not
    /// stop the app from starting.
    static func theme(named name: String?) -> Theme {
        guard let name else { return .dark }
        return Theme.named(name) ?? .dark
    }

    // MARK: - Rendering

    /// The single place an `AnsiRenderer` is built, so no caller can quietly
    /// omit a setting. One did: the in-memory edit re-render used to drop the
    /// mermaid options, so an unsaved edit drew diagrams that `mermaid: false`
    /// had switched off, until the next reload put them back.
    func render(_ source: String, width: Int) -> RenderedDocument {
        AnsiRenderer(width: width, theme: theme, headingBanners: headingBanners,
                     mermaidEnabled: mermaidEnabled, mermaidCharset: mermaidCharset).render(source)
    }

    /// nil when the file cannot be read — deleted or permission-denied between
    /// the picker listing it and the pager opening it.
    func renderFile(_ url: URL, width: Int) -> RenderedDocument? {
        guard let source = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return render(source, width: width)
    }

    // MARK: - Theme selector

    /// Swap the theme for a live preview, without persisting it.
    func previewTheme(_ name: String) {
        theme = RenderContext.theme(named: name)
    }

    /// Swap the theme and write it to the global config.
    func saveTheme(_ name: String) {
        theme = RenderContext.theme(named: name)
        themeName = name
        AppConfig.setTheme(name)
    }
}
