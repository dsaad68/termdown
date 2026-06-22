// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// Canvas drawing: node boxes, straight/diagonal line segments, layer merging
// (with junction resolution), and the top-level draw()/drawMap orchestration.

import Foundation

func drawBox(_ n: Node, _ g: Graph) -> Canvas {
    guard let gc = n.gridCoord else { return mkDrawing(0, 0) }
    let w = g.columnWidth[gc.x, default: 0] + g.columnWidth[gc.x + 1, default: 0]
    let h = g.rowHeight[gc.y, default: 0] + g.rowHeight[gc.y + 1, default: 0]

    let fromX = 0, fromY = 0
    let toX = w, toY = h
    let box = mkDrawing(max(fromX, toX), max(fromY, toY))

    let (horiz, vert, tl, tr, bl, br): (String, String, String, String, String, String)
    if !g.useAscii {
        (horiz, vert, tl, tr, bl, br) = ("─", "│", "┌", "┐", "└", "┘")
    } else {
        (horiz, vert, tl, tr, bl, br) = ("-", "|", "+", "+", "+", "+")
    }
    for x in (fromX + 1)..<toX {
        box[x, fromY] = horiz
        box[x, toY] = horiz
    }
    for y in (fromY + 1)..<toY {
        box[fromX, y] = vert
        box[toX, y] = vert
    }
    box[fromX, fromY] = tl
    box[toX, fromY] = tr
    box[fromX, toY] = bl
    box[toX, toY] = br

    // Centered label lines inside the padded content area.
    let innerTop = fromY + 1
    let innerHeight = h - 1
    let contentTop = innerTop + (innerHeight - n.label.contentHeight()) / 2
    let colorHex = n.styleClass.styles["color"] ?? ""
    for (lineIdx, line) in n.label.lines.enumerated() {
        let textY = contentTop + lineIdx * (graphLabelLineGap + 1)
        let textWidth = DisplayWidth.stringWidth(line)
        var textX = fromX + w / 2 - ceilDiv(textWidth, 2) + 1
        for scalar in line.unicodeScalars {
            let rw = max(DisplayWidth.scalarWidth(scalar), 1)
            box[textX, textY] = wrapTextInColor(String(scalar), colorHex, colorEnabled: g.colorEnabled)
            var offset = 1
            while offset < rw {
                box[textX + offset, textY] = ""
                offset += 1
            }
            textX += rw
        }
    }
    return box
}

extension Graph {
    /// Draw a straight or diagonal segment, returning the cells written.
    /// `offsetFrom`/`offsetTo` trim the ends (mermaid-ascii uses 1 / -1).
    func drawLine(_ d: Canvas, _ from: Coord, _ to: Coord, _ offsetFrom: Int, _ offsetTo: Int) -> [Coord] {
        let dir = determineDirection(from, to)
        var drawn: [Coord] = []
        let v = useAscii ? "|" : "│"
        let hLine = useAscii ? "-" : "─"
        let diagBack = useAscii ? "\\" : "╲"
        let diagFwd = useAscii ? "/" : "╱"

        switch dir {
        case Dir.up:
            var y = from.y - offsetFrom
            while y >= to.y - offsetTo {
                drawn.append(Coord(x: from.x, y: y)); d[from.x, y] = v; y -= 1
            }
        case Dir.down:
            var y = from.y + offsetFrom
            while y <= to.y + offsetTo {
                drawn.append(Coord(x: from.x, y: y)); d[from.x, y] = v; y += 1
            }
        case Dir.left:
            var x = from.x - offsetFrom
            while x >= to.x - offsetTo {
                drawn.append(Coord(x: x, y: from.y)); d[x, from.y] = hLine; x -= 1
            }
        case Dir.right:
            var x = from.x + offsetFrom
            while x <= to.x + offsetTo {
                drawn.append(Coord(x: x, y: from.y)); d[x, from.y] = hLine; x += 1
            }
        case Dir.upperLeft:
            var x = from.x, y = from.y - offsetFrom
            while x >= to.x - offsetTo, y >= to.y - offsetTo {
                drawn.append(Coord(x: x, y: y)); d[x, y] = diagBack; x -= 1; y -= 1
            }
        case Dir.upperRight:
            var x = from.x, y = from.y - offsetFrom
            while x <= to.x + offsetTo, y >= to.y - offsetTo {
                drawn.append(Coord(x: x, y: y)); d[x, y] = diagFwd; x += 1; y -= 1
            }
        case Dir.lowerLeft:
            var x = from.x, y = from.y + offsetFrom
            while x >= to.x - offsetTo, y <= to.y + offsetTo {
                drawn.append(Coord(x: x, y: y)); d[x, y] = diagFwd; x -= 1; y += 1
            }
        case Dir.lowerRight:
            var x = from.x, y = from.y + offsetFrom
            while x <= to.x + offsetTo, y <= to.y + offsetTo {
                drawn.append(Coord(x: x, y: y)); d[x, y] = diagBack; x += 1; y += 1
            }
        default:
            break
        }
        return drawn
    }

    func drawNode(_ n: Node) {
        guard let dc = n.drawingCoord, let nd = n.drawing else { return }
        drawing = mergeDrawings(drawing, dc, [nd])
    }

    func mergeDrawings(_ base: Canvas, _ mergeCoord: Coord, _ drawings: [Canvas]) -> Canvas {
        var maxX = base.sizeX
        var maxY = base.sizeY
        for d in drawings {
            maxX = max(maxX, d.sizeX + mergeCoord.x)
            maxY = max(maxY, d.sizeY + mergeCoord.y)
        }
        let merged = mkDrawing(maxX, maxY)
        for x in 0...max(maxX, 0) where x < base.d.count {
            for y in 0...max(maxY, 0) where y < base.d[x].count {
                merged[x, y] = base[x, y]
            }
        }
        for d in drawings {
            for x in 0..<d.d.count {
                for y in 0..<d.d[x].count {
                    let c = d[x, y]
                    if c != " " {
                        let tx = x + mergeCoord.x
                        let ty = y + mergeCoord.y
                        let current = merged[tx, ty]
                        if !useAscii, isJunctionChar(c), isJunctionChar(current) {
                            merged[tx, ty] = mergeJunctions(current, c)
                        } else {
                            merged[tx, ty] = c
                        }
                    }
                }
            }
        }
        return merged
    }

    func draw() -> Canvas {
        drawSubgraphs()

        for node in nodes where !node.drawn { drawNode(node) }

        var lineDrawings: [Canvas] = []
        var cornerDrawings: [Canvas] = []
        var arrowHeadDrawings: [Canvas] = []
        var boxStartDrawings: [Canvas] = []
        var labelDrawings: [Canvas] = []
        for edge in edges {
            let (line, boxStart, arrowHead, corners, label) = drawEdge(edge)
            if let line { lineDrawings.append(line) }
            if let corners { cornerDrawings.append(corners) }
            if let arrowHead { arrowHeadDrawings.append(arrowHead) }
            if let boxStart { boxStartDrawings.append(boxStart) }
            if let label { labelDrawings.append(label) }
        }

        let origin = Coord(x: 0, y: 0)
        drawing = mergeDrawings(drawing, origin, lineDrawings)
        drawing = mergeDrawings(drawing, origin, cornerDrawings)
        drawing = mergeDrawings(drawing, origin, arrowHeadDrawings)
        drawing = mergeDrawings(drawing, origin, boxStartDrawings)
        drawing = mergeDrawings(drawing, origin, labelDrawings)

        drawSubgraphLabels()
        return drawing
    }
}

func drawMap(_ properties: GraphProperties, colorEnabled: Bool) -> String {
    let g = mkGraph(properties)
    g.setStyleClasses(properties)
    g.paddingX = properties.paddingX
    g.paddingY = properties.paddingY
    g.useAscii = properties.useAscii
    g.colorEnabled = colorEnabled
    g.setSubgraphs(properties.subgraphs)
    g.createMapping()
    let d = g.draw()
    return drawingToString(d)
}
