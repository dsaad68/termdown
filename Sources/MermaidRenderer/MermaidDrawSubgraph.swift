// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// Subgraph rendering: frames drawn outermost-first (so children sit on top),
// and labels drawn last so edges don't overwrite them.

import Foundation

func drawSubgraph(_ sg: Subgraph, _ g: Graph) -> Canvas {
    let width = sg.maxX - sg.minX
    let height = sg.maxY - sg.minY
    if width <= 0 || height <= 0 { return mkDrawing(0, 0) }

    let fromX = 0, fromY = 0, toX = width, toY = height
    let d = mkDrawing(width, height)
    let (h, v, tl, tr, bl, br): (String, String, String, String, String, String) =
        g.useAscii ? ("-", "|", "+", "+", "+", "+") : ("─", "│", "┌", "┐", "└", "┘")

    for x in (fromX + 1)..<toX {
        d[x, fromY] = h
        d[x, toY] = h
    }
    for y in (fromY + 1)..<toY {
        d[fromX, y] = v
        d[toX, y] = v
    }
    d[fromX, fromY] = tl
    d[toX, fromY] = tr
    d[fromX, toY] = bl
    d[toX, toY] = br
    return d
}

func drawSubgraphLabel(_ sg: Subgraph, _ g: Graph) -> (Canvas, Coord) {
    let width = sg.maxX - sg.minX
    let height = sg.maxY - sg.minY
    if width <= 0 || height <= 0 { return (mkDrawing(0, 0), Coord(x: 0, y: 0)) }

    let fromX = 0, fromY = 0, toX = width
    let d = mkDrawing(width, height)
    for (lineIdx, line) in sg.label.lines.enumerated() {
        let labelY = fromY + 1 + lineIdx * (graphLabelLineGap + 1)
        var labelX = fromX + width / 2 - DisplayWidth.stringWidth(line) / 2
        if labelX < fromX + 1 { labelX = fromX + 1 }
        for scalar in line.unicodeScalars {
            let rw = max(DisplayWidth.scalarWidth(scalar), 1)
            if labelX < toX { d[labelX, labelY] = String(scalar) }
            var offset = 1
            while offset < rw, labelX + offset < toX {
                d[labelX + offset, labelY] = ""
                offset += 1
            }
            labelX += rw
        }
    }
    return (d, Coord(x: sg.minX, y: sg.minY))
}

extension Graph {
    func drawSubgraphs() {
        for sg in sortSubgraphsByDepth() {
            let sgDrawing = drawSubgraph(sg, self)
            drawing = mergeDrawings(drawing, Coord(x: sg.minX, y: sg.minY), [sgDrawing])
        }
    }

    func drawSubgraphLabels() {
        for sg in subgraphs where !sg.nodes.isEmpty {
            let (labelDrawing, offset) = drawSubgraphLabel(sg, self)
            drawing = mergeDrawings(drawing, offset, [labelDrawing])
        }
    }

    func sortSubgraphsByDepth() -> [Subgraph] {
        var depths: [ObjectIdentifier: Int] = [:]
        for sg in subgraphs { depths[ObjectIdentifier(sg)] = getSubgraphDepth(sg) }
        var sorted = subgraphs
        for i in 0..<sorted.count {
            for j in (i + 1)..<sorted.count
                where depths[ObjectIdentifier(sorted[i])]! > depths[ObjectIdentifier(sorted[j])]! {
                sorted.swapAt(i, j)
            }
        }
        return sorted
    }

    func getSubgraphDepth(_ sg: Subgraph) -> Int {
        guard let parent = sg.parent else { return 0 }
        return 1 + getSubgraphDepth(parent)
    }
}
