// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// Edge drawing: path segments, the box-start T-junction, the arrowhead, path
// corners, and the centered edge label. Each is drawn onto its own blank layer
// (copyCanvas) so the caller can merge them in a fixed z-order.

import Foundation

extension Canvas {
    func drawTextOnLine(_ line: [Coord], _ label: String) {
        guard line.count >= 2 else { return }
        let minX = min(line[0].x, line[1].x)
        let maxX = max(line[0].x, line[1].x)
        let minY = min(line[0].y, line[1].y)
        let maxY = max(line[0].y, line[1].y)
        let middleX = minX + (maxX - minX) / 2
        let middleY = minY + (maxY - minY) / 2
        let start = Coord(x: middleX - label.utf8.count / 2, y: middleY)
        drawText(start, label)
    }
}

private func unicodeArrow(_ dir: Coord) -> String? {
    switch dir {
    case Dir.up: return "▲"
    case Dir.down: return "▼"
    case Dir.left: return "◄"
    case Dir.right: return "►"
    case Dir.upperRight: return "◥"
    case Dir.upperLeft: return "◤"
    case Dir.lowerRight: return "◢"
    case Dir.lowerLeft: return "◣"
    default: return nil
    }
}

private func asciiArrow(_ dir: Coord) -> String? {
    switch dir {
    case Dir.up: return "^"
    case Dir.down: return "v"
    case Dir.left: return "<"
    case Dir.right: return ">"
    default: return nil
    }
}

extension Graph {
    func drawEdge(_ e: Edge) -> (Canvas?, Canvas?, Canvas?, Canvas?, Canvas?) {
        guard let fromGC = e.from.gridCoord, let toGC = e.to.gridCoord else {
            return (nil, nil, nil, nil, nil)
        }
        let from = fromGC.direction(e.startDir)
        let to = toGC.direction(e.endDir)
        return drawArrow(from, to, e)
    }

    func drawArrow(_ from: Coord, _ to: Coord, _ e: Edge) -> (Canvas?, Canvas?, Canvas?, Canvas?, Canvas?) {
        guard e.path.count >= 2 else { return (nil, nil, nil, nil, nil) }
        let dLabel = drawArrowLabel(e)
        let (dPath, linesDrawn, lineDirs) = drawPath(e.path)
        guard !linesDrawn.isEmpty else { return (nil, nil, nil, nil, nil) }
        let dBoxStart = drawBoxStart(e.path, linesDrawn[0])
        let dArrowHead = drawArrowHead(linesDrawn[linesDrawn.count - 1], lineDirs[lineDirs.count - 1])
        let dCorners = drawCorners(e.path)
        return (dPath, dBoxStart, dArrowHead, dCorners, dLabel)
    }

    func drawPath(_ path: [Coord]) -> (Canvas, [[Coord]], [Coord]) {
        let d = copyCanvas(drawing)
        var previousCoord = path[0]
        var linesDrawn: [[Coord]] = []
        var lineDirs: [Coord] = []
        for nextCoord in path[1...] {
            let previousDrawingCoord = gridToDrawingCoord(previousCoord, nil)
            let nextDrawingCoord = gridToDrawingCoord(nextCoord, nil)
            if previousDrawingCoord == nextDrawingCoord { continue }
            let dir = determineDirection(previousCoord, nextCoord)
            var s = drawLine(d, previousDrawingCoord, nextDrawingCoord, 1, -1)
            if s.isEmpty { s.append(previousDrawingCoord) }
            linesDrawn.append(s)
            lineDirs.append(dir)
            previousCoord = nextCoord
        }
        return (d, linesDrawn, lineDirs)
    }

    func drawBoxStart(_ path: [Coord], _ firstLine: [Coord]) -> Canvas {
        let d = copyCanvas(drawing)
        guard path.count >= 2, let from = firstLine.first else { return d }
        if useAscii { return d }
        let dir = determineDirection(path[0], path[1])
        switch dir {
        case Dir.up: d[from.x, from.y + 1] = "┴"
        case Dir.down: d[from.x, from.y - 1] = "┬"
        case Dir.left: d[from.x + 1, from.y] = "┤"
        case Dir.right: d[from.x - 1, from.y] = "├"
        default: break
        }
        return d
    }

    func drawArrowHead(_ line: [Coord], _ fallback: Coord) -> Canvas {
        let d = copyCanvas(drawing)
        guard let from = line.first else { return d }
        let lastPos = line[line.count - 1]
        var dir = determineDirection(from, lastPos)
        if line.count == 1 || dir == Dir.middle { dir = fallback }

        let char: String
        if !useAscii {
            char = unicodeArrow(dir) ?? unicodeArrow(fallback) ?? "●"
        } else {
            char = asciiArrow(dir) ?? asciiArrow(fallback) ?? "*"
        }
        d[lastPos.x, lastPos.y] = char
        return d
    }

    func drawCorners(_ path: [Coord]) -> Canvas {
        let d = copyCanvas(drawing)
        for (idx, coord) in path.enumerated() {
            if idx == 0 || idx == path.count - 1 { continue }
            let dc = gridToDrawingCoord(coord, nil)
            let prevDir = determineDirection(path[idx - 1], coord)
            let nextDir = determineDirection(coord, path[idx + 1])

            var corner = "+"
            if !useAscii {
                if (prevDir == Dir.right && nextDir == Dir.down) || (prevDir == Dir.up && nextDir == Dir.left) {
                    corner = "┐"
                } else if (prevDir == Dir.right && nextDir == Dir.up) || (prevDir == Dir.down && nextDir == Dir.left) {
                    corner = "┘"
                } else if (prevDir == Dir.left && nextDir == Dir.down) || (prevDir == Dir.up && nextDir == Dir.right) {
                    corner = "┌"
                } else if (prevDir == Dir.left && nextDir == Dir.up) || (prevDir == Dir.down && nextDir == Dir.right) {
                    corner = "└"
                } else {
                    corner = "+"
                }
            }
            d[dc.x, dc.y] = corner
        }
        return d
    }

    func drawArrowLabel(_ e: Edge) -> Canvas {
        let d = copyCanvas(drawing)
        if e.text.isEmpty { return d }
        guard e.labelLine.count >= 2 else { return d }
        d.drawTextOnLine(lineToDrawing(e.labelLine), e.text)
        return d
    }
}
