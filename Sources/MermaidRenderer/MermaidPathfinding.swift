// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// A* edge routing over the grid. The priority queue replicates Go's
// container/heap binary-heap algorithm (sift up/down) so that ties — which the
// comparison leaves unordered — break in the same order, keeping output
// byte-identical to mermaid-ascii.

import Foundation

private struct PQItem {
    var coord: Coord
    var priority: Int
}

private struct PriorityQueue {
    private var items: [PQItem] = []

    var isEmpty: Bool { items.isEmpty }

    mutating func push(_ item: PQItem) {
        items.append(item)
        up(items.count - 1)
    }

    mutating func pop() -> Coord {
        let n = items.count - 1
        items.swapAt(0, n)
        down(0, n)
        return items.removeLast().coord
    }

    private func less(_ i: Int, _ j: Int) -> Bool {
        items[i].priority < items[j].priority
    }

    private mutating func up(_ j0: Int) {
        var j = j0
        while true {
            let i = (j - 1) / 2
            if i == j || !less(j, i) { break }
            items.swapAt(i, j)
            j = i
        }
    }

    private mutating func down(_ i0: Int, _ n: Int) {
        var i = i0
        while true {
            let j1 = 2 * i + 1
            if j1 >= n || j1 < 0 { break }
            var j = j1
            let j2 = j1 + 1
            if j2 < n, less(j2, j1) { j = j2 }
            if !less(j, i) { break }
            items.swapAt(i, j)
            i = j
        }
    }
}

func heuristic(_ a: Coord, _ b: Coord) -> Int {
    let absX = abs(a.x - b.x)
    let absY = abs(a.y - b.y)
    if absX == 0 || absY == 0 {
        return absX + absY
    }
    // Punish for taking an extra corner; we prefer straight lines.
    return absX + absY + 1
}

func mergePath(_ path: [Coord]) -> [Coord] {
    if path.count <= 2 { return path }
    var indexToRemove = Set<Int>()
    var step0 = path[0]
    var step1 = path[1]
    for (idx, step2) in path[2...].enumerated() {
        let prevDir = determineDirection(step0, step1)
        let dir = determineDirection(step1, step2)
        if prevDir == dir { indexToRemove.insert(idx + 1) }
        step0 = step1
        step1 = step2
    }
    var newPath: [Coord] = []
    for (idx, step) in path.enumerated() where !indexToRemove.contains(idx) {
        newPath.append(step)
    }
    return newPath
}

extension Graph {
    func isFreeInGrid(_ c: Coord) -> Bool {
        if c.x < 0 || c.y < 0 { return false }
        return grid[c] == nil
    }

    /// A* from `from` to `to`. Returns nil when no path exists.
    func getPath(_ from: Coord, _ to: Coord) -> [Coord]? {
        var pq = PriorityQueue()
        pq.push(PQItem(coord: from, priority: 0))

        var costSoFar: [Coord: Int] = [from: 0]
        var cameFrom: [Coord: Coord] = [:] // `from` intentionally absent (no predecessor)

        let directions = [
            Coord(x: 1, y: 0), Coord(x: -1, y: 0),
            Coord(x: 0, y: 1), Coord(x: 0, y: -1),
        ]

        while !pq.isEmpty {
            let current = pq.pop()

            if current == to {
                var path: [Coord] = []
                var c: Coord? = current
                while let cc = c {
                    path.insert(cc, at: 0)
                    c = cameFrom[cc]
                }
                return path
            }

            for dir in directions {
                let next = Coord(x: current.x + dir.x, y: current.y + dir.y)
                if !isFreeInGrid(next), next != to { continue }

                let newCost = costSoFar[current]! + 1
                if costSoFar[next] == nil || newCost < costSoFar[next]! {
                    costSoFar[next] = newCost
                    pq.push(PQItem(coord: next, priority: newCost + heuristic(next, to)))
                    cameFrom[next] = current
                }
            }
        }
        return nil
    }
}
