// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// Per-edge path determination (including parallel/duplicate-edge offsets) and
// label-line selection. `len(e.text)` is a byte count in Go, so we use UTF-8
// byte length here to keep multibyte label corridors sized identically.

import Foundation

func labelMiddleX(_ line: [Coord]) -> Int {
    var minX = line[0].x
    var maxX = line[1].x
    if minX > maxX { swap(&minX, &maxX) }
    return minX + (maxX - minX) / 2
}

extension Graph {
    func determinePath(_ e: Edge) {
        let key = newEdgePair(e.from.index, e.to.index)
        let duplicateIndex = edgeCounts[key, default: 0]

        if let (startDir, endDir) = parallelDirections(e, duplicateIndex) {
            let from = e.from.gridCoord!.direction(startDir)
            let to = e.to.gridCoord!.direction(endDir)
            if let path = getPath(from, to) {
                e.startDir = startDir
                e.endDir = endDir
                e.path = mergePath(path)
                edgeCounts[key, default: 0] += 1
                return
            }
        }

        var alternativePath: [Coord] = []
        let (preferredDir, preferredOppositeDir, alternativeDir, alternativeOppositeDir) =
            determineStartAndEndDir(e)

        var from = e.from.gridCoord!.direction(preferredDir)
        var to = e.to.gridCoord!.direction(preferredOppositeDir)
        guard let rawPreferred = getPath(from, to) else {
            e.startDir = alternativeDir
            e.endDir = alternativeOppositeDir
            e.path = alternativePath
            return
        }
        let preferredPath = mergePath(rawPreferred)

        from = e.from.gridCoord!.direction(alternativeDir)
        to = e.to.gridCoord!.direction(alternativeOppositeDir)
        let rawAlternative = getPath(from, to)
        if rawAlternative == nil {
            e.startDir = preferredDir
            e.endDir = preferredOppositeDir
            e.path = preferredPath
        }
        alternativePath = mergePath(rawAlternative ?? [])

        if preferredPath.count <= alternativePath.count {
            e.startDir = preferredDir
            e.endDir = preferredOppositeDir
            e.path = preferredPath
        } else {
            e.startDir = alternativeDir
            e.endDir = alternativeOppositeDir
            e.path = alternativePath
        }
        edgeCounts[key, default: 0] += 1
    }

    /// Start/end faces for parallel (duplicate) edges; nil to use the default.
    func parallelDirections(_ e: Edge, _ duplicateIndex: Int) -> (Coord, Coord)? {
        if duplicateIndex == 0 { return nil }
        let dir = determineDirection(e.from.gridCoord!, e.to.gridCoord!)
        if graphDirection == "LR", dir == Dir.right || dir == Dir.left {
            let options: [(Coord, Coord)] = [(Dir.down, Dir.down), (Dir.up, Dir.up)]
            if duplicateIndex - 1 < options.count { return options[duplicateIndex - 1] }
        } else if graphDirection == "TD", dir == Dir.down || dir == Dir.up {
            let options: [(Coord, Coord)] = [(Dir.right, Dir.right), (Dir.left, Dir.left)]
            if duplicateIndex - 1 < options.count { return options[duplicateIndex - 1] }
        }
        return nil
    }

    func determineLabelLine(_ e: Edge) {
        let lenLabel = e.text.utf8.count
        if lenLabel == 0 { return }
        guard e.path.count >= 2 else { return }

        var prevStep = e.path[0]
        var largestLine: [Coord]?
        var largestLineSize = 0
        var fallbackLine: [Coord]?
        var fallbackLineSize = 0

        for step in e.path[1...] {
            let line = [prevStep, step]
            prevStep = step
            let lineWidth = calculateLineWidth(line)
            if isNodeColumn(labelMiddleX(line)) {
                if lineWidth > fallbackLineSize {
                    fallbackLineSize = lineWidth
                    fallbackLine = line
                }
                continue
            }
            if lineWidth >= lenLabel {
                largestLine = line
                break
            }
            if lineWidth > largestLineSize {
                largestLineSize = lineWidth
                largestLine = line
            }
        }
        if largestLine == nil { largestLine = fallbackLine }
        if largestLine == nil { largestLine = [e.path[0], e.path[1]] }

        let chosen = largestLine!
        let middleX = labelMiddleX(chosen)
        columnWidth[middleX] = max(columnWidth[middleX, default: 0], lenLabel + 2)
        e.labelLine = chosen
    }

    func isNodeColumn(_ x: Int) -> Bool {
        for n in nodes {
            guard let gc = n.gridCoord else { continue }
            if x >= gc.x, x <= gc.x + 2 { return true }
        }
        return false
    }

    func calculateLineWidth(_ line: [Coord]) -> Int {
        var total = 0
        for c in line { total += columnWidth[c.x, default: 0] }
        return total
    }
}
