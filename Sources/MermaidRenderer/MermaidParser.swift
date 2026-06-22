// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// Flowchart parser: line-based, ordered regex patterns matched in priority
// order, producing an insertion-ordered node → edges map plus node specs,
// style classes and subgraphs.

import Foundation

/// Run `pattern` against `s`; return [fullMatch, group1, group2, …] or nil.
func regexGroups(_ pattern: String, _ s: String, dotAll: Bool = true) -> [String]? {
    var opts: NSRegularExpression.Options = []
    if dotAll { opts.insert(.dotMatchesLineSeparators) }
    guard let re = try? NSRegularExpression(pattern: pattern, options: opts) else { return nil }
    let range = NSRange(s.startIndex..., in: s)
    guard let m = re.firstMatch(in: s, options: [], range: range) else { return nil }
    var groups: [String] = []
    for i in 0..<m.numberOfRanges {
        if let r = Range(m.range(at: i), in: s) {
            groups.append(String(s[r]))
        } else {
            groups.append("")
        }
    }
    return groups
}

private func trimQuotes(_ s: String) -> String {
    var sub = Substring(s)
    while sub.first == "\"" { sub = sub.dropFirst() }
    while sub.last == "\"" { sub = sub.dropLast() }
    return String(sub)
}

func parseSubgraphHeader(_ header: String) -> TextSubgraph {
    let trimmed = header.trimmingCharacters(in: .whitespaces)
    var labelText = trimmed
    var id = ""
    if let m = regexGroups(#"^(\S+)\s*\[(.+)\]$"#, trimmed) {
        id = m[1].trimmingCharacters(in: .whitespaces)
        labelText = trimQuotes(m[2].trimmingCharacters(in: .whitespaces))
    }
    return TextSubgraph(id: id, name: labelText, label: newGraphLabel(labelText))
}

func splitGraphLines(_ mermaid: String) -> [String] {
    var result: [String] = []
    var current = ""
    var bracketDepth = 0
    var inQuotes = false
    let chars = Array(mermaid)
    var i = 0
    while i < chars.count {
        let c = chars[i]
        var skip = false
        switch c {
        case "\"":
            inQuotes.toggle()
        case "[":
            if !inQuotes { bracketDepth += 1 }
        case "]":
            if !inQuotes, bracketDepth > 0 { bracketDepth -= 1 }
        case "\n":
            if bracketDepth == 0 {
                result.append(current)
                current = ""
                skip = true
            }
        case "\\":
            if i + 1 < chars.count, chars[i + 1] == "n", bracketDepth == 0 {
                result.append(current)
                current = ""
                i += 1
                skip = true
            }
        default:
            break
        }
        if !skip { current.append(c) }
        i += 1
    }
    result.append(current)
    return result
}

func parseNode(_ line: String) -> TextNode {
    var trimmed = line.trimmingCharacters(in: .whitespaces)
    var styleClass = ""
    if let r = trimmed.range(of: ":::", options: .backwards) {
        styleClass = String(trimmed[r.upperBound...]).trimmingCharacters(in: .whitespaces)
        trimmed = String(trimmed[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
    }
    let name = trimmed
    if let open = trimmed.range(of: "["),
       open.lowerBound > trimmed.startIndex,
       trimmed.hasSuffix("]") {
        let nm = String(trimmed[..<open.lowerBound]).trimmingCharacters(in: .whitespaces)
        let beforeClose = trimmed.index(before: trimmed.endIndex)
        var labelText = String(trimmed[open.upperBound..<beforeClose]).trimmingCharacters(in: .whitespaces)
        labelText = trimQuotes(labelText)
        return TextNode(name: nm, label: newGraphLabel(labelText), hasLabel: true, styleClass: styleClass)
    }
    return TextNode(name: name, label: newGraphLabel(name), hasLabel: false, styleClass: styleClass)
}

func parseStyleClass(name: String, styles: String) -> StyleClass {
    var styleMap: [String: String] = [:]
    for style in styles.components(separatedBy: ",") {
        let kv = style.components(separatedBy: ":")
        if kv.count >= 2 { styleMap[kv[0]] = kv[1] }
    }
    return StyleClass(name: name, styles: styleMap)
}

extension GraphProperties {
    /// Parse a single line into nodes, or nil if no pattern matches.
    func parseString(_ line: String) -> [TextNode]? {
        if regexGroups(#"^\s*$"#, line) != nil { return [] }
        if let m = regexGroups(#"^(.+)\s*-->\s*\|(.+)\|\s*(.+)$"#, line) {
            let lhs = parseString(m[1]) ?? [parseNode(m[1])]
            let rhs = parseString(m[3]) ?? [parseNode(m[3])]
            return setArrowWithLabel(lhs, rhs, label: m[2])
        }
        if let m = regexGroups(#"^(.+)\s*-->\s*(.+)$"#, line) {
            let lhs = parseString(m[1]) ?? [parseNode(m[1])]
            let rhs = parseString(m[2]) ?? [parseNode(m[2])]
            return setArrow(lhs, rhs)
        }
        if let m = regexGroups(#"^classDef\s+(.+)\s+(.+)$"#, line) {
            let s = parseStyleClass(name: m[1], styles: m[2])
            styleClasses[s.name] = s
            return []
        }
        if let m = regexGroups(#"^(.+) & (.+)$"#, line) {
            let lhs = parseString(m[1]) ?? [parseNode(m[1])]
            let rhs = parseString(m[2]) ?? [parseNode(m[2])]
            return lhs + rhs
        }
        return nil
    }

    func setArrowWithLabel(_ lhs: [TextNode], _ rhs: [TextNode], label: String) -> [TextNode] {
        for l in lhs {
            for r in rhs {
                setData(parent: l, edge: TextEdge(parent: l, child: r, label: label))
            }
        }
        return rhs
    }

    func setArrow(_ lhs: [TextNode], _ rhs: [TextNode]) -> [TextNode] {
        setArrowWithLabel(lhs, rhs, label: "")
    }

    func rememberNode(_ node: TextNode) {
        var spec = nodeSpecs[node.name] ?? .empty
        if node.hasLabel || spec.label.lines.isEmpty {
            spec.label = node.label
            spec.labelIsExplicit = node.hasLabel
        }
        if !node.styleClass.isEmpty { spec.styleClass = node.styleClass }
        nodeSpecs[node.name] = spec
    }

    func addNode(_ node: TextNode) {
        rememberNode(node)
        if data.get(node.name) == nil { data.set(node.name, []) }
    }

    func setData(parent: TextNode, edge: TextEdge) {
        rememberNode(parent)
        rememberNode(edge.child)
        if let children = data.get(parent.name) {
            data.set(parent.name, children + [edge])
        } else {
            data.set(parent.name, [edge])
        }
        if data.get(edge.child.name) == nil {
            data.set(edge.child.name, [])
        }
    }
}

/// mermaid-ascii `mermaidFileToMap`. Defaults: borderPadding 1, paddingX/Y 5.
func mermaidFileToMap(_ mermaid: String, styleType: String) throws -> GraphProperties {
    let rawLines = splitGraphLines(mermaid)

    var lines: [String] = []
    for var line in rawLines {
        if line == "---" { break }
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("%%") { continue }
        if let r = line.range(of: "%%") {
            line = String(line[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        if !line.trimmingCharacters(in: .whitespaces).isEmpty { lines.append(line) }
    }

    let properties = GraphProperties(styleType: styleType, boxBorderPadding: 1, paddingX: 5, paddingY: 5)

    // Optional padding directives before the graph definition.
    while let first = lines.first {
        let trimmed = first.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { lines.removeFirst(); continue }
        if let m = regexGroups(#"^(?i)padding([xy])\s*=\s*(\d+)$"#, trimmed), let value = Int(m[2]) {
            if m[1].lowercased() == "x" { properties.paddingX = value } else { properties.paddingY = value }
            lines.removeFirst()
            continue
        }
        break
    }

    guard let header = lines.first else { throw MermaidError.missingGraphDefinition }
    switch header {
    case "graph LR", "flowchart LR":
        properties.graphDirection = "LR"
    case "graph TD", "flowchart TD", "graph TB", "flowchart TB":
        properties.graphDirection = "TD"
    default:
        throw MermaidError.unsupportedGraphType(header)
    }
    lines.removeFirst()

    var subgraphStack: [TextSubgraph] = []

    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)

        if let m = regexGroups(#"^\s*subgraph\s+(.+)$"#, trimmedLine) {
            let h = parseSubgraphHeader(m[1])
            let newSubgraph = TextSubgraph(id: h.id, name: h.name, label: h.label)
            if let parent = subgraphStack.last {
                newSubgraph.parent = parent
                parent.children.append(newSubgraph)
            }
            subgraphStack.append(newSubgraph)
            properties.subgraphs.append(newSubgraph)
            continue
        }

        if regexGroups(#"^\s*end\s*$"#, trimmedLine) != nil {
            if !subgraphStack.isEmpty { subgraphStack.removeLast() }
            continue
        }

        let existingNodes = Set(properties.data.keys)

        if let nodes = properties.parseString(line) {
            for node in nodes { properties.addNode(node) }
        } else {
            properties.addNode(parseNode(line))
        }

        if !subgraphStack.isEmpty {
            for nodeName in properties.data.keys where !existingNodes.contains(nodeName) {
                for sg in subgraphStack where !sg.nodes.contains(nodeName) {
                    sg.nodes.append(nodeName)
                }
            }
        }
    }

    return properties
}
