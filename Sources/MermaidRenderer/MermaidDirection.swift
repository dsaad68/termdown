// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// Per-edge start/end direction selection (mermaid-ascii direction.go). Picks
// which face of each box an edge leaves/enters, with special handling for
// backwards-flowing edges so they route around rather than through.

import Foundation

extension Graph {
    func selfReferenceDirection() -> (Coord, Coord, Coord, Coord) {
        if graphDirection == "LR" {
            return (Dir.right, Dir.down, Dir.down, Dir.right)
        }
        return (Dir.down, Dir.right, Dir.right, Dir.down)
    }

    // Returns (preferredDir, preferredOppositeDir, alternativeDir, alternativeOppositeDir).
    func determineStartAndEndDir(_ e: Edge) -> (Coord, Coord, Coord, Coord) {
        if e.from === e.to { return selfReferenceDirection() }
        let d = determineDirection(e.from.gridCoord!, e.to.gridCoord!)

        var preferredDir = Dir.middle
        var preferredOppositeDir = Dir.middle
        var alternativeDir = Dir.middle
        var alternativeOppositeDir = Dir.middle

        var isBackwards = false
        if graphDirection == "LR" {
            isBackwards = (d == Dir.left || d == Dir.upperLeft || d == Dir.lowerLeft)
        } else {
            isBackwards = (d == Dir.up || d == Dir.upperLeft || d == Dir.upperRight)
        }

        switch d {
        case Dir.lowerRight:
            if graphDirection == "LR" {
                preferredDir = Dir.down; preferredOppositeDir = Dir.left
                alternativeDir = Dir.right; alternativeOppositeDir = Dir.up
            } else {
                preferredDir = Dir.right; preferredOppositeDir = Dir.up
                alternativeDir = Dir.down; alternativeOppositeDir = Dir.left
            }
        case Dir.upperRight:
            if graphDirection == "LR" {
                preferredDir = Dir.up; preferredOppositeDir = Dir.left
                alternativeDir = Dir.right; alternativeOppositeDir = Dir.down
            } else {
                preferredDir = Dir.right; preferredOppositeDir = Dir.down
                alternativeDir = Dir.up; alternativeOppositeDir = Dir.left
            }
        case Dir.lowerLeft:
            if graphDirection == "LR" {
                preferredDir = Dir.down; preferredOppositeDir = Dir.down
                alternativeDir = Dir.left; alternativeOppositeDir = Dir.up
            } else {
                preferredDir = Dir.left; preferredOppositeDir = Dir.up
                alternativeDir = Dir.down; alternativeOppositeDir = Dir.right
            }
        case Dir.upperLeft:
            if graphDirection == "LR" {
                preferredDir = Dir.down; preferredOppositeDir = Dir.down
                alternativeDir = Dir.left; alternativeOppositeDir = Dir.down
            } else {
                preferredDir = Dir.right; preferredOppositeDir = Dir.right
                alternativeDir = Dir.up; alternativeOppositeDir = Dir.right
            }
        default:
            if isBackwards {
                if graphDirection == "LR", d == Dir.left {
                    preferredDir = Dir.down; preferredOppositeDir = Dir.down
                    alternativeDir = Dir.left; alternativeOppositeDir = Dir.right
                } else if graphDirection == "TD", d == Dir.up {
                    preferredDir = Dir.right; preferredOppositeDir = Dir.right
                    alternativeDir = Dir.up; alternativeOppositeDir = Dir.down
                } else {
                    preferredDir = d; preferredOppositeDir = getOpposite(d)
                    alternativeDir = d; alternativeOppositeDir = preferredOppositeDir
                }
            } else {
                preferredDir = d; preferredOppositeDir = getOpposite(d)
                alternativeDir = d; alternativeOppositeDir = preferredOppositeDir
            }
        }
        return (preferredDir, preferredOppositeDir, alternativeDir, alternativeOppositeDir)
    }
}
