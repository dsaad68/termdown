// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff).
// https://github.com/AlexanderGrooff/mermaid-ascii — see NOTICE.
//
// Coordinate + direction primitives. mermaid-ascii uses three nominally
// distinct types (genericCoord/gridCoord/drawingCoord) that are all an (x, y)
// pair; we unify them as `Coord`. A `direction` is itself an (x, y) offset into
// a node's 3x3 grid block, so the direction constants double as offsets and as
// the values returned by `determineDirection`.

import Foundation

struct Coord: Hashable {
    var x: Int
    var y: Int

    /// Offset this coordinate by a direction (mermaid-ascii `gridCoord.Direction`).
    func direction(_ dir: Coord) -> Coord {
        Coord(x: x + dir.x, y: y + dir.y)
    }
}

/// Direction constants — offsets within a node's 3x3 grid block.
enum Dir {
    static let up = Coord(x: 1, y: 0)
    static let down = Coord(x: 1, y: 2)
    static let left = Coord(x: 0, y: 1)
    static let right = Coord(x: 2, y: 1)
    static let upperRight = Coord(x: 2, y: 0)
    static let upperLeft = Coord(x: 0, y: 0)
    static let lowerRight = Coord(x: 2, y: 2)
    static let lowerLeft = Coord(x: 0, y: 2)
    static let middle = Coord(x: 1, y: 1)
}

func getOpposite(_ d: Coord) -> Coord {
    switch d {
    case Dir.up: return Dir.down
    case Dir.down: return Dir.up
    case Dir.left: return Dir.right
    case Dir.right: return Dir.left
    case Dir.upperRight: return Dir.lowerLeft
    case Dir.upperLeft: return Dir.lowerRight
    case Dir.lowerRight: return Dir.upperLeft
    case Dir.lowerLeft: return Dir.upperRight
    default: return Dir.middle
    }
}

/// Classify the direction from `from` to `to` (mermaid-ascii `determineDirection`).
func determineDirection(_ from: Coord, _ to: Coord) -> Coord {
    if from.x == to.x {
        return from.y < to.y ? Dir.down : Dir.up
    } else if from.y == to.y {
        return from.x < to.x ? Dir.right : Dir.left
    } else if from.x < to.x {
        return from.y < to.y ? Dir.lowerRight : Dir.upperRight
    } else {
        return from.y < to.y ? Dir.lowerLeft : Dir.upperLeft
    }
}

// Integer helpers mirroring mermaid-ascii's math.go.
@inline(__always) func ceilDiv(_ x: Int, _ y: Int) -> Int {
    x % y == 0 ? x / y : x / y + 1
}
