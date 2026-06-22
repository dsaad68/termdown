// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// Parser-side data structures. mermaid-ascii uses an insertion-ordered map
// (elliotchance/orderedmap) for node → outgoing edges; we replicate the
// ordering with a keys array + dictionary.

import Foundation

final class OrderedMap<Value> {
    private(set) var keys: [String] = []
    private var dict: [String: Value] = [:]

    func get(_ key: String) -> Value? { dict[key] }

    func set(_ key: String, _ value: Value) {
        if dict[key] == nil { keys.append(key) }
        dict[key] = value
    }

    /// Insertion-ordered (key, value) pairs (mermaid-ascii Front()/Next()).
    var pairs: [(String, Value)] { keys.map { ($0, dict[$0]!) } }
}

struct TextNode {
    var name: String
    var label: GraphLabel
    var hasLabel: Bool = false
    var styleClass: String = ""
}

struct GraphNodeSpec {
    var label: GraphLabel
    var labelIsExplicit: Bool
    var styleClass: String

    /// Zero value: an empty (lines == []) label, matching Go's zero struct.
    static let empty = GraphNodeSpec(
        label: GraphLabel(lines: [], width: 0), labelIsExplicit: false, styleClass: "")
}

struct TextEdge {
    var parent: TextNode
    var child: TextNode
    var label: String
}

final class TextSubgraph {
    var id: String
    var name: String
    var label: GraphLabel
    var nodes: [String]
    weak var parent: TextSubgraph?
    var children: [TextSubgraph]

    init(id: String, name: String, label: GraphLabel,
         nodes: [String] = [], parent: TextSubgraph? = nil, children: [TextSubgraph] = []) {
        self.id = id
        self.name = name
        self.label = label
        self.nodes = nodes
        self.parent = parent
        self.children = children
    }
}

final class GraphProperties {
    var data = OrderedMap<[TextEdge]>()
    var nodeSpecs: [String: GraphNodeSpec] = [:]
    var styleClasses: [String: StyleClass] = [:]
    var boxBorderPadding: Int
    var graphDirection: String = ""
    var styleType: String
    var paddingX: Int
    var paddingY: Int
    var subgraphs: [TextSubgraph] = []
    var useAscii = false

    init(styleType: String, boxBorderPadding: Int, paddingX: Int, paddingY: Int) {
        self.styleType = styleType
        self.boxBorderPadding = boxBorderPadding
        self.paddingX = paddingX
        self.paddingY = paddingY
    }
}

enum MermaidError: Error {
    case unsupportedGraphType(String)
    case unsupportedSyntax(String)
    case missingGraphDefinition
    case parseFailure(String)
    case notADiagram
}
