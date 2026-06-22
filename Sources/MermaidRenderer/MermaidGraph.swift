// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// The graph model (nodes / edges / subgraphs / grid) and its construction from
// parsed properties. Nodes, edges and subgraphs are reference types to mirror
// the pointer semantics (and identity comparisons) of the Go original.

import Foundation

final class Node {
    var name: String
    var label: GraphLabel
    var drawing: Canvas?
    var drawingCoord: Coord?
    var gridCoord: Coord?
    var drawn = false
    var index: Int
    var styleClassName: String
    var styleClass = StyleClass(name: "", styles: [:])

    init(name: String, label: GraphLabel, index: Int, styleClassName: String) {
        self.name = name
        self.label = label
        self.index = index
        self.styleClassName = styleClassName
    }
}

final class Edge {
    var from: Node
    var to: Node
    var text: String
    var path: [Coord] = []
    var labelLine: [Coord] = []
    var startDir = Dir.middle
    var endDir = Dir.middle

    init(from: Node, to: Node, text: String) {
        self.from = from
        self.to = to
        self.text = text
    }
}

struct EdgePair: Hashable {
    var from: Int
    var to: Int
}

func newEdgePair(_ from: Int, _ to: Int) -> EdgePair {
    from < to ? EdgePair(from: from, to: to) : EdgePair(from: to, to: from)
}

final class Subgraph {
    var name: String
    var label: GraphLabel
    var nodes: [Node] = []
    weak var parent: Subgraph?
    var children: [Subgraph] = []
    var minX = 0
    var minY = 0
    var maxX = 0
    var maxY = 0

    init(name: String, label: GraphLabel) {
        self.name = name
        self.label = label
    }
}

final class Graph {
    var nodes: [Node] = []
    var edges: [Edge] = []
    var drawing: Canvas = mkDrawing(0, 0)
    var grid: [Coord: Node] = [:]
    var edgeCounts: [EdgePair: Int] = [:]
    var columnWidth: [Int: Int] = [:]
    var rowHeight: [Int: Int] = [:]
    var styleClasses: [String: StyleClass] = [:]
    var styleType = ""
    var boxBorderPadding = 0
    var graphDirection = ""
    var paddingX = 0
    var paddingY = 0
    var subgraphs: [Subgraph] = []
    var offsetX = 0
    var offsetY = 0
    var useAscii = false
    var colorEnabled = false

    func getNode(_ name: String) -> Node? {
        for n in nodes where n.name == name { return n }
        return nil
    }

    func appendNode(_ n: Node) {
        nodes.append(n)
    }

    func getEdgesFromNode(_ n: Node) -> [Edge] {
        edges.filter { $0.from.name == n.name }
    }

    func getChildren(_ n: Node) -> [Node] {
        getEdgesFromNode(n).map { $0.to }
    }

    func gridToDrawingCoord(_ c: Coord, _ dir: Coord? = nil) -> Coord {
        var x = 0
        var y = 0
        let target = dir == nil ? c : Coord(x: c.x + dir!.x, y: c.y + dir!.y)
        var column = 0
        while column < target.x {
            x += columnWidth[column, default: 0]
            column += 1
        }
        var row = 0
        while row < target.y {
            y += rowHeight[row, default: 0]
            row += 1
        }
        return Coord(
            x: x + columnWidth[target.x, default: 0] / 2 + offsetX,
            y: y + rowHeight[target.y, default: 0] / 2 + offsetY)
    }

    func lineToDrawing(_ line: [Coord]) -> [Coord] {
        line.map { gridToDrawingCoord($0, nil) }
    }

    func setStyleClasses(_ properties: GraphProperties) {
        styleClasses = properties.styleClasses
        styleType = properties.styleType
        boxBorderPadding = properties.boxBorderPadding
        graphDirection = properties.graphDirection
        paddingX = properties.paddingX
        paddingY = properties.paddingY
        for n in nodes where !n.styleClassName.isEmpty {
            n.styleClass = styleClasses[n.styleClassName] ?? StyleClass(name: "", styles: [:])
        }
    }

    func setSubgraphs(_ textSubgraphs: [TextSubgraph]) {
        subgraphs = []
        for tsg in textSubgraphs {
            let sg = Subgraph(name: tsg.name, label: tsg.label)
            for nodeName in tsg.nodes {
                if let node = getNode(nodeName) { sg.nodes.append(node) }
            }
            subgraphs.append(sg)
        }
        // Parent / child relationships, matched by position.
        for (i, tsg) in textSubgraphs.enumerated() {
            let sg = subgraphs[i]
            if let parentTsg = tsg.parent {
                for (j, candidate) in textSubgraphs.enumerated() where candidate === parentTsg {
                    sg.parent = subgraphs[j]
                    break
                }
            }
            for childTsg in tsg.children {
                for (j, candidate) in textSubgraphs.enumerated() where candidate === childTsg {
                    sg.children.append(subgraphs[j])
                    break
                }
            }
        }
    }
}

func mkGraph(_ properties: GraphProperties) -> Graph {
    let g = Graph()
    var index = 0
    for (nodeName, children) in properties.data.pairs {
        let spec = properties.nodeSpecs[nodeName] ?? .empty
        var parentNode = g.getNode(nodeName)
        if parentNode == nil {
            let n = Node(name: nodeName, label: spec.label, index: index, styleClassName: spec.styleClass)
            g.appendNode(n)
            index += 1
            parentNode = n
        }
        for textEdge in children {
            let childSpec = properties.nodeSpecs[textEdge.child.name] ?? .empty
            var childNode = g.getNode(textEdge.child.name)
            if childNode == nil {
                let n = Node(
                    name: textEdge.child.name, label: childSpec.label,
                    index: index, styleClassName: childSpec.styleClass)
                g.appendNode(n)
                index += 1
                childNode = n
            }
            g.edges.append(Edge(from: parentNode!, to: childNode!, text: textEdge.label))
        }
    }
    return g
}
