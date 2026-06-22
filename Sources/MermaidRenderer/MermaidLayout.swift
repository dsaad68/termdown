// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// Grid layout: assign each node a 3x3 grid block, size columns/rows, route
// edges, then translate the grid into the drawing canvas. Mirrors
// mermaid-ascii's createMapping pipeline step for step.

import Foundation

extension Graph {
    func createMapping() {
        // Level → next free cross-axis position (Go uses a fixed 100-slot array
        // of zeros; a default-0 dictionary is equivalent for all reachable levels).
        var highestPositionPerLevel: [Int: Int] = [:]

        var nodesFound = Set<String>()
        var rootNodes: [Node] = []
        for n in nodes {
            if !nodesFound.contains(n.name) { rootNodes.append(n) }
            nodesFound.insert(n.name)
            for child in getChildren(n) { nodesFound.insert(child.name) }
        }

        var hasExternalRoots = false
        var hasSubgraphRootsWithEdges = false
        for n in rootNodes {
            if isNodeInAnySubgraph(n) {
                if !getChildren(n).isEmpty { hasSubgraphRootsWithEdges = true }
            } else {
                hasExternalRoots = true
            }
        }

        let shouldSeparate = graphDirection == "LR" && hasExternalRoots && hasSubgraphRootsWithEdges

        var externalRootNodes: [Node] = []
        var subgraphRootNodes: [Node] = []
        if shouldSeparate {
            for n in rootNodes {
                if isNodeInAnySubgraph(n) { subgraphRootNodes.append(n) } else { externalRootNodes.append(n) }
            }
        } else {
            externalRootNodes = rootNodes
        }

        for n in externalRootNodes {
            let requested = graphDirection == "LR"
                ? Coord(x: 0, y: highestPositionPerLevel[0, default: 0])
                : Coord(x: highestPositionPerLevel[0, default: 0], y: 0)
            n.gridCoord = reserveSpotInGrid(n, requested)
            highestPositionPerLevel[0, default: 0] += 4
        }

        if shouldSeparate, !subgraphRootNodes.isEmpty {
            let subgraphLevel = 4
            for n in subgraphRootNodes {
                let requested = graphDirection == "LR"
                    ? Coord(x: subgraphLevel, y: highestPositionPerLevel[subgraphLevel, default: 0])
                    : Coord(x: highestPositionPerLevel[subgraphLevel, default: 0], y: subgraphLevel)
                n.gridCoord = reserveSpotInGrid(n, requested)
                highestPositionPerLevel[subgraphLevel, default: 0] += 4
            }
        }

        for n in nodes {
            guard let gc = n.gridCoord else { continue }
            let childLevel = graphDirection == "LR" ? gc.x + 4 : gc.y + 4
            var highestPosition = highestPositionPerLevel[childLevel, default: 0]
            for child in getChildren(n) where child.gridCoord == nil {
                let requested = graphDirection == "LR"
                    ? Coord(x: childLevel, y: highestPosition)
                    : Coord(x: highestPosition, y: childLevel)
                child.gridCoord = reserveSpotInGrid(child, requested)
                highestPosition += 4
                highestPositionPerLevel[childLevel] = highestPosition
            }
        }

        for n in nodes { setColumnWidth(n) }

        for e in edges {
            determinePath(e)
            increaseGridSizeForPath(e.path)
            determineLabelLine(e)
        }

        // Last point before we manipulate the drawing.
        for n in nodes {
            guard let gc = n.gridCoord else { continue }
            n.drawingCoord = gridToDrawingCoord(gc, nil)
            n.drawing = drawBox(n, self)
        }
        setDrawingSizeToGridConstraints()
        calculateSubgraphBoundingBoxes()
        offsetDrawingForSubgraphs()
    }

    func setColumnWidth(_ n: Node) {
        guard let gc = n.gridCoord else { return }
        let col1 = 1
        let col2 = 2 * boxBorderPadding + n.label.width
        let col3 = 1
        let colsToBePlaced = [col1, col2, col3]
        let rowsToBePlaced = [1, n.label.contentHeight() + 2 * boxBorderPadding, 1]

        for (idx, col) in colsToBePlaced.enumerated() {
            let xCoord = gc.x + idx
            columnWidth[xCoord] = max(columnWidth[xCoord, default: 0], col)
        }
        for (idx, row) in rowsToBePlaced.enumerated() {
            let yCoord = gc.y + idx
            rowHeight[yCoord] = max(rowHeight[yCoord, default: 0], row)
        }

        if gc.x > 0 {
            columnWidth[gc.x - 1] = paddingX
        }
        if gc.y > 0 {
            var basePadding = paddingY
            if hasIncomingEdgeFromOutsideSubgraph(n) {
                basePadding += 4 // subgraph overhead
            }
            rowHeight[gc.y - 1] = max(rowHeight[gc.y - 1, default: 0], basePadding)
        }
    }

    func increaseGridSizeForPath(_ path: [Coord]) {
        for c in path {
            if columnWidth[c.x] == nil { columnWidth[c.x] = paddingX / 2 }
            if rowHeight[c.y] == nil { rowHeight[c.y] = paddingY / 2 }
        }
    }

    func reserveSpotInGrid(_ n: Node, _ requestedCoord: Coord) -> Coord {
        if grid[requestedCoord] != nil {
            let next = graphDirection == "LR"
                ? Coord(x: requestedCoord.x, y: requestedCoord.y + 4)
                : Coord(x: requestedCoord.x + 4, y: requestedCoord.y)
            return reserveSpotInGrid(n, next)
        }
        for x in 0..<3 {
            for y in 0..<3 {
                grid[Coord(x: requestedCoord.x + x, y: requestedCoord.y + y)] = n
            }
        }
        n.gridCoord = requestedCoord
        return requestedCoord
    }

    func setDrawingSizeToGridConstraints() {
        var maxX = 0
        for (_, w) in columnWidth { maxX += w }
        var maxY = 0
        for (_, h) in rowHeight { maxY += h }
        drawing.increaseSize(maxX - 1, maxY - 1)
    }
}
