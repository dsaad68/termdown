// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// Box-drawing character sets for sequence diagrams (pkg/sequence/charset.go).

import Foundation

struct SequenceBoxChars {
    let topLeft: String
    let topRight: String
    let bottomLeft: String
    let bottomRight: String
    let horizontal: String
    let vertical: String
    let teeDown: String
    let teeRight: String
    let teeLeft: String
    let cross: String
    let arrowRight: String
    let arrowLeft: String
    let solidLine: String
    let dottedLine: String
    let selfTopRight: String
    let selfBottom: String
}

let sequenceASCII = SequenceBoxChars(
    topLeft: "+", topRight: "+", bottomLeft: "+", bottomRight: "+",
    horizontal: "-", vertical: "|", teeDown: "+", teeRight: "+", teeLeft: "+",
    cross: "+", arrowRight: ">", arrowLeft: "<", solidLine: "-", dottedLine: ".",
    selfTopRight: "+", selfBottom: "+")

let sequenceUnicode = SequenceBoxChars(
    topLeft: "┌", topRight: "┐", bottomLeft: "└", bottomRight: "┘",
    horizontal: "─", vertical: "│", teeDown: "┬", teeRight: "├", teeLeft: "┤",
    cross: "┼", arrowRight: "►", arrowLeft: "◄", solidLine: "─", dottedLine: "┈",
    selfTopRight: "┐", selfBottom: "┘")
