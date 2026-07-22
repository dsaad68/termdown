// MermaidRenderer — a native Swift port of mermaid-ascii (MIT, © 2023 Alexander
// Grooff). See NOTICE. Public entry point: `Mermaid.render`.

import Foundation

public enum MermaidCharset: Sendable {
    case unicode
    case ascii
}

public struct MermaidOptions: Sendable {
    /// Box-drawing character set.
    public var charset: MermaidCharset = .unicode
    /// Whether classDef `color:` styling is emitted as truecolor ANSI.
    public var colorEnabled = true
    /// Horizontal space between nodes (mermaid-ascii -x, default 5).
    public var paddingX = 5
    /// Vertical space between nodes (mermaid-ascii -y, default 5).
    public var paddingY = 5
    /// Padding between text and border (mermaid-ascii -p, default 1).
    public var borderPadding = 1
    /// Display columns available to the diagram, or nil for its natural size.
    ///
    /// When set, node labels wrap and inter-node spacing tightens until the
    /// diagram fits. A diagram can still exceed it — an edge label is drawn
    /// inline along a one-row arrow and cannot wrap — so callers must not
    /// assume the result fits. nil reproduces the unconstrained layout exactly.
    public var maxWidth: Int?

    public init() {}
}

public enum Mermaid {
    /// Render Mermaid `source` to diagram rows, or nil if it isn't a supported,
    /// parseable diagram (callers should then fall back to the raw source).
    public static func render(_ source: String, options: MermaidOptions = .init()) -> [String]? {
        guard let text = renderToString(source, options: options) else { return nil }
        return text.components(separatedBy: "\n")
    }

    /// Render to a single newline-joined string (no trailing newline).
    public static func renderToString(_ source: String, options: MermaidOptions = .init()) -> String? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if isSequenceDiagram(trimmed) {
            return renderSequence(source, options: options)
        }
        do {
            let properties = try mermaidFileToMap(source, styleType: "cli")
            properties.useAscii = options.charset == .ascii
            properties.boxBorderPadding = options.borderPadding
            properties.paddingX = options.paddingX
            properties.paddingY = options.paddingY
            properties.maxWidth = options.maxWidth
            return drawMap(properties, colorEnabled: options.colorEnabled)
        } catch {
            return nil
        }
    }
}
