// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// Sequence diagram renderer (pkg/sequence/renderer.go): participant boxes,
// lifelines, messages and self-messages laid out on a character grid.

import Foundation

private let defaultSelfMessageWidth = 4
private let defaultMessageSpacing = 1
private let defaultParticipantSpacing = 5
private let boxPaddingLeftRight = 2
private let minBoxWidth = 3
private let boxBorderWidth = 2
private let labelLeftMargin = 2
private let labelBufferSpace = 10

private struct SequenceLayout {
    var participantWidths: [Int]
    var participantCenters: [Int]
    var totalWidth: Int
    var messageSpacing: Int
    var selfMessageWidth: Int
}

private func calculateLayout(_ sd: ParsedSequence) -> SequenceLayout {
    let participantSpacing = defaultParticipantSpacing

    let widths = sd.participants.map { p -> Int in
        max(DisplayWidth.stringWidth(p.label) + boxPaddingLeftRight, minBoxWidth)
    }

    var centers = [Int](repeating: 0, count: sd.participants.count)
    var currentX = 0
    for i in sd.participants.indices {
        let boxWidth = widths[i] + boxBorderWidth
        if i == 0 {
            centers[i] = boxWidth / 2
            currentX = boxWidth
        } else {
            currentX += participantSpacing
            centers[i] = currentX + boxWidth / 2
            currentX += boxWidth
        }
    }
    let last = sd.participants.count - 1
    let totalWidth = centers[last] + (widths[last] + boxBorderWidth) / 2

    return SequenceLayout(
        participantWidths: widths, participantCenters: centers, totalWidth: totalWidth,
        messageSpacing: defaultMessageSpacing, selfMessageWidth: defaultSelfMessageWidth)
}

private func trimRight(_ chars: [Character]) -> String {
    var end = chars.count
    while end > 0, chars[end - 1] == " " { end -= 1 }
    return String(chars[0..<end])
}

/// Working row pre-filled with spaces and lifeline verticals.
private func lifelineCells(_ layout: SequenceLayout, _ chars: SequenceBoxChars, minLen: Int = 0) -> [Character] {
    let n = max(layout.totalWidth + 1, minLen)
    var line = [Character](repeating: " ", count: n)
    let vertical = Character(chars.vertical)
    for c in layout.participantCenters where c >= 0 && c < n { line[c] = vertical }
    return line
}

private func buildLifeline(_ layout: SequenceLayout, _ chars: SequenceBoxChars) -> String {
    trimRight(lifelineCells(layout, chars))
}

private func buildLine(_ sd: ParsedSequence, _ layout: SequenceLayout, _ draw: (Int) -> String) -> String {
    var sb = ""
    for i in sd.participants.indices {
        let boxWidth = layout.participantWidths[i] + boxBorderWidth
        let left = layout.participantCenters[i] - boxWidth / 2
        let needed = left - sb.unicodeScalars.count
        if needed > 0 { sb += String(repeating: " ", count: needed) }
        sb += draw(i)
    }
    return sb
}

private func renderMessage(_ msg: SequenceMessage, _ layout: SequenceLayout, _ chars: SequenceBoxChars) -> [String] {
    var lines: [String] = []
    let from = layout.participantCenters[msg.from.index]
    let to = layout.participantCenters[msg.to.index]

    var label = msg.label
    if msg.number > 0 { label = "\(msg.number). \(msg.label)" }

    if !label.isEmpty {
        let start = min(from, to) + labelLeftMargin
        let labelWidth = DisplayWidth.stringWidth(label)
        let w = max(layout.totalWidth, start + labelWidth) + labelBufferSpace
        var line = lifelineCells(layout, chars, minLen: w)
        var col = start
        for scalar in label.unicodeScalars where col < line.count {
            line[col] = Character(scalar)
            col += 1
        }
        lines.append(trimRight(line))
    }

    var line = lifelineCells(layout, chars, minLen: max(from, to) + 2)
    let style = msg.arrowType == .dotted ? chars.dottedLine : chars.solidLine
    if from < to {
        line[from] = Character(chars.teeRight)
        var i = from + 1
        while i < to { line[i] = Character(style); i += 1 }
        line[to - 1] = Character(chars.arrowRight)
        line[to] = Character(chars.vertical)
    } else {
        line[to] = Character(chars.vertical)
        line[to + 1] = Character(chars.arrowLeft)
        var i = to + 2
        while i < from { line[i] = Character(style); i += 1 }
        line[from] = Character(chars.teeLeft)
    }
    lines.append(trimRight(line))
    return lines
}

private func renderSelfMessage(_ msg: SequenceMessage, _ layout: SequenceLayout, _ chars: SequenceBoxChars) -> [String] {
    var lines: [String] = []
    let center = layout.participantCenters[msg.from.index]
    let width = layout.selfMessageWidth
    let target = layout.totalWidth + width + 1

    func ensure(_ minLen: Int) -> [Character] {
        lifelineCells(layout, chars, minLen: max(target, minLen))
    }

    var label = msg.label
    if msg.number > 0 { label = "\(msg.number). \(msg.label)" }

    if !label.isEmpty {
        let start = center + labelLeftMargin
        let labelWidth = DisplayWidth.stringWidth(label)
        let needed = start + labelWidth + labelBufferSpace
        var line = ensure(needed)
        var col = start
        for scalar in label.unicodeScalars where col < line.count {
            line[col] = Character(scalar)
            col += 1
        }
        lines.append(trimRight(line))
    }

    var l1 = ensure(0)
    l1[center] = Character(chars.teeRight)
    var i = 1
    while i < width { l1[center + i] = Character(chars.horizontal); i += 1 }
    l1[center + width - 1] = Character(chars.selfTopRight)
    lines.append(trimRight(l1))

    var l2 = ensure(0)
    l2[center + width - 1] = Character(chars.vertical)
    lines.append(trimRight(l2))

    var l3 = ensure(0)
    l3[center] = Character(chars.vertical)
    l3[center + 1] = Character(chars.arrowLeft)
    var k = 2
    while k < width - 1 { l3[center + k] = Character(chars.horizontal); k += 1 }
    l3[center + width - 1] = Character(chars.selfBottom)
    lines.append(trimRight(l3))

    return lines
}

func renderSequenceDiagram(_ sd: ParsedSequence, useAscii: Bool) -> String {
    let chars = useAscii ? sequenceASCII : sequenceUnicode
    let layout = calculateLayout(sd)
    var lines: [String] = []

    lines.append(buildLine(sd, layout) { i in
        chars.topLeft + String(repeating: chars.horizontal, count: layout.participantWidths[i]) + chars.topRight
    })
    lines.append(buildLine(sd, layout) { i in
        let w = layout.participantWidths[i]
        let labelLen = DisplayWidth.stringWidth(sd.participants[i].label)
        let pad = (w - labelLen) / 2
        return chars.vertical + String(repeating: " ", count: max(0, pad)) + sd.participants[i].label
            + String(repeating: " ", count: max(0, w - pad - labelLen)) + chars.vertical
    })
    lines.append(buildLine(sd, layout) { i in
        let w = layout.participantWidths[i]
        return chars.bottomLeft + String(repeating: chars.horizontal, count: w / 2)
            + chars.teeDown + String(repeating: chars.horizontal, count: max(0, w - w / 2 - 1))
            + chars.bottomRight
    })

    for msg in sd.messages {
        for _ in 0..<layout.messageSpacing { lines.append(buildLifeline(layout, chars)) }
        if msg.from === msg.to {
            lines.append(contentsOf: renderSelfMessage(msg, layout, chars))
        } else {
            lines.append(contentsOf: renderMessage(msg, layout, chars))
        }
    }
    lines.append(buildLifeline(layout, chars))
    return lines.joined(separator: "\n") + "\n"
}

/// Bridge for the public entry point (drops the trailing newline so the framing
/// matches graph output).
func renderSequence(_ source: String, options: MermaidOptions) -> String? {
    guard let sd = try? parseSequence(source) else { return nil }
    var out = renderSequenceDiagram(sd, useAscii: options.charset == .ascii)
    if out.hasSuffix("\n") { out.removeLast() }
    return out
}
