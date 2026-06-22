// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// The 2D character canvas (`drawing` = [][]string in Go). Cells are indexed
// [x][y]; the canvas is always rectangular and pre-filled with spaces. Writes
// out of bounds are ignored (Go would panic; for a viewer we degrade instead).

import Foundation

final class Canvas {
    // d[x][y]
    var d: [[String]]

    /// mkDrawing(x, y): an (x+1) by (y+1) grid of spaces.
    init(x: Int, y: Int) {
        let cols = max(x + 1, 0)
        let rows = max(y + 1, 0)
        d = Array(repeating: Array(repeating: " ", count: rows), count: cols)
    }

    /// getDrawingSize: largest valid index on each axis (len - 1).
    var sizeX: Int { d.count - 1 }
    var sizeY: Int { d.isEmpty ? -1 : d[0].count - 1 }

    subscript(_ x: Int, _ y: Int) -> String {
        get {
            guard x >= 0, x < d.count, y >= 0, y < d[x].count else { return " " }
            return d[x][y]
        }
        set {
            guard x >= 0, x < d.count, y >= 0, y < d[x].count else { return }
            d[x][y] = newValue
        }
    }

    func increaseSize(_ x: Int, _ y: Int) {
        let newX = max(x, sizeX)
        let newY = max(y, sizeY)
        if newX == sizeX, newY == sizeY { return }
        var nd = Array(repeating: Array(repeating: " ", count: newY + 1), count: newX + 1)
        for i in 0..<d.count {
            let col = d[i]
            for j in 0..<col.count {
                nd[i][j] = col[j]
            }
        }
        d = nd
    }

    /// Place plain text starting at `start`, advancing by display width and
    /// blanking the trailing cells of wide runes (mermaid-ascii `drawText`).
    func drawText(_ start: Coord, _ text: String) {
        let textWidth = DisplayWidth.stringWidth(text)
        increaseSize(start.x + textWidth, start.y)
        var textX = start.x
        for scalar in text.unicodeScalars {
            let rw = max(DisplayWidth.scalarWidth(scalar), 1)
            self[textX, start.y] = String(scalar)
            var offset = 1
            while offset < rw {
                self[textX + offset, start.y] = ""
                offset += 1
            }
            textX += rw
        }
    }
}

func mkDrawing(_ x: Int, _ y: Int) -> Canvas {
    Canvas(x: x, y: y)
}

/// copyCanvas returns a *blank* canvas of the same size (mermaid-ascii relies on
/// this — each edge element is drawn onto its own blank layer then merged).
func copyCanvas(_ c: Canvas) -> Canvas {
    Canvas(x: c.sizeX, y: c.sizeY)
}

func drawingToString(_ c: Canvas) -> String {
    let maxX = c.sizeX
    let maxY = c.sizeY
    var out = ""
    var y = 0
    while y <= maxY {
        var x = 0
        while x <= maxX {
            out += c[x, y]
            x += 1
        }
        if y != maxY { out += "\n" }
        y += 1
    }
    return out
}

let junctionChars: Set<String> = [
    "─", "│", "┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼",
    "╴", "╵", "╶", "╷",
]

func isJunctionChar(_ c: String) -> Bool {
    junctionChars.contains(c)
}

private let junctionMap: [String: [String: String]] = [
    "─": ["│": "┼", "┌": "┬", "┐": "┬", "└": "┴", "┘": "┴", "├": "┼", "┤": "┼", "┬": "┬", "┴": "┴"],
    "│": ["─": "┼", "┌": "├", "┐": "┤", "└": "├", "┘": "┤", "├": "├", "┤": "┤", "┬": "┼", "┴": "┼"],
    "┌": ["─": "┬", "│": "├", "┐": "┬", "└": "├", "┘": "┼", "├": "├", "┤": "┼", "┬": "┬", "┴": "┼"],
    "┐": ["─": "┬", "│": "┤", "┌": "┬", "└": "┼", "┘": "┤", "├": "┼", "┤": "┤", "┬": "┬", "┴": "┼"],
    "└": ["─": "┴", "│": "├", "┌": "├", "┐": "┼", "┘": "┴", "├": "├", "┤": "┼", "┬": "┼", "┴": "┴"],
    "┘": ["─": "┴", "│": "┤", "┌": "┼", "┐": "┤", "└": "┴", "├": "┼", "┤": "┤", "┬": "┼", "┴": "┴"],
    "├": ["─": "┼", "│": "├", "┌": "├", "┐": "┼", "└": "├", "┘": "┼", "┤": "┼", "┬": "┼", "┴": "┼"],
    "┤": ["─": "┼", "│": "┤", "┌": "┼", "┐": "┤", "└": "┼", "┘": "┤", "├": "┼", "┬": "┼", "┴": "┼"],
    "┬": ["─": "┬", "│": "┼", "┌": "┬", "┐": "┬", "└": "┼", "┘": "┼", "├": "┼", "┤": "┼", "┴": "┼"],
    "┴": ["─": "┴", "│": "┼", "┌": "┼", "┐": "┼", "└": "┴", "┘": "┴", "├": "┼", "┤": "┼", "┬": "┼"],
]

func mergeJunctions(_ c1: String, _ c2: String) -> String {
    if let merged = junctionMap[c1]?[c2] {
        return merged
    }
    return c1
}
