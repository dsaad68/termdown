// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// Subgraph membership queries and bounding-box / spacing / offset computation.

import Foundation

extension Graph {
    func isNodeInAnySubgraph(_ n: Node) -> Bool {
        for sg in subgraphs {
            for sgNode in sg.nodes where sgNode === n { return true }
        }
        return false
    }

    func getNodeSubgraph(_ n: Node) -> Subgraph? {
        for sg in subgraphs {
            for sgNode in sg.nodes where sgNode === n { return sg }
        }
        return nil
    }

    func hasIncomingEdgeFromOutsideSubgraph(_ n: Node) -> Bool {
        guard let nodeSubgraph = getNodeSubgraph(n) else { return false }

        var hasExternalEdge = false
        for edge in edges where edge.to === n {
            if getNodeSubgraph(edge.from) !== nodeSubgraph {
                hasExternalEdge = true
                break
            }
        }
        if !hasExternalEdge { return false }

        // Only apply overhead to the topmost node (lowest Y) with external edges.
        for otherNode in nodeSubgraph.nodes {
            if otherNode === n || otherNode.gridCoord == nil { continue }
            var otherHasExternal = false
            for edge in edges where edge.to === otherNode {
                if getNodeSubgraph(edge.from) !== nodeSubgraph {
                    otherHasExternal = true
                    break
                }
            }
            if otherHasExternal, let og = otherNode.gridCoord, let ng = n.gridCoord, og.y < ng.y {
                return false
            }
        }
        return true
    }

    func calculateSubgraphBoundingBoxes() {
        for sg in subgraphs { calculateSubgraphBoundingBox(sg) }
        ensureSubgraphSpacing()
    }

    func calculateSubgraphBoundingBox(_ sg: Subgraph) {
        if sg.nodes.isEmpty { return }

        var minX = 1_000_000
        var minY = 1_000_000
        var maxX = -1_000_000
        var maxY = -1_000_000

        for child in sg.children {
            calculateSubgraphBoundingBox(child)
            if !child.nodes.isEmpty {
                minX = min(minX, child.minX)
                minY = min(minY, child.minY)
                maxX = max(maxX, child.maxX)
                maxY = max(maxY, child.maxY)
            }
        }

        for node in sg.nodes {
            guard let dc = node.drawingCoord, let drawing = node.drawing else { continue }
            let nodeMinX = dc.x
            let nodeMinY = dc.y
            let nodeMaxX = nodeMinX + drawing.d.count - 1
            let nodeMaxY = nodeMinY + (drawing.d.first?.count ?? 0) - 1
            minX = min(minX, nodeMinX)
            minY = min(minY, nodeMinY)
            maxX = max(maxX, nodeMaxX)
            maxY = max(maxY, nodeMaxY)
        }

        // Ensure the title fits inside the frame after padding.
        let currentWidth = maxX - minX
        let currentInnerWidth = currentWidth + 3
        if currentInnerWidth < sg.label.width {
            let extraWidth = sg.label.width - currentInnerWidth
            minX -= extraWidth / 2
            maxX += extraWidth - (extraWidth / 2)
        }

        let subgraphPadding = 2
        let subgraphLabelSpace = sg.label.contentHeight() + 1
        sg.minX = minX - subgraphPadding
        sg.minY = minY - subgraphPadding - subgraphLabelSpace
        sg.maxX = maxX + subgraphPadding
        sg.maxY = maxY + subgraphPadding
    }

    func ensureSubgraphSpacing() {
        let minSpacing = 1
        let rootSubgraphs = subgraphs.filter { $0.parent == nil && !$0.nodes.isEmpty }

        for i in 0..<rootSubgraphs.count {
            for j in (i + 1)..<rootSubgraphs.count {
                let sg1 = rootSubgraphs[i]
                let sg2 = rootSubgraphs[j]

                // Vertical overlap (TD layout).
                if sg1.minX < sg2.maxX, sg1.maxX > sg2.minX {
                    if sg1.maxY >= sg2.minY - minSpacing, sg1.minY < sg2.minY {
                        sg2.minY = sg1.maxY + minSpacing + 1
                    } else if sg2.maxY >= sg1.minY - minSpacing, sg2.minY < sg1.minY {
                        sg1.minY = sg2.maxY + minSpacing + 1
                    }
                }

                // Horizontal overlap (LR layout).
                if sg1.minY < sg2.maxY, sg1.maxY > sg2.minY {
                    if sg1.maxX >= sg2.minX - minSpacing, sg1.minX < sg2.minX {
                        sg2.minX = sg1.maxX + minSpacing + 1
                    } else if sg2.maxX >= sg1.minX - minSpacing, sg2.minX < sg1.minX {
                        sg1.minX = sg2.maxX + minSpacing + 1
                    }
                }
            }
        }
    }

    func offsetDrawingForSubgraphs() {
        if subgraphs.isEmpty { return }

        var minX = 0
        var minY = 0
        for sg in subgraphs {
            minX = min(minX, sg.minX)
            minY = min(minY, sg.minY)
        }

        let dx = -minX
        let dy = -minY
        if dx == 0, dy == 0 { return }

        offsetX = dx
        offsetY = dy

        for sg in subgraphs {
            sg.minX += dx
            sg.minY += dy
            sg.maxX += dx
            sg.maxY += dy
        }

        for n in nodes {
            if let dc = n.drawingCoord {
                n.drawingCoord = Coord(x: dc.x + dx, y: dc.y + dy)
            }
        }
    }
}
