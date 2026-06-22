// Ported from mermaid-ascii (MIT, © 2023 Alexander Grooff). See NOTICE.
//
// Sequence diagram parser (pkg/sequence/parser.go): participants, messages,
// and the autonumber directive.

import Foundation

private let sequenceDiagramKeyword = "sequenceDiagram"
private let solidArrowSyntax = "->>"
private let dottedArrowSyntax = "-->>"

enum SequenceArrowType {
    case solid
    case dotted
}

final class SequenceParticipant {
    var id: String
    var label: String
    var index: Int
    init(id: String, label: String, index: Int) {
        self.id = id
        self.label = label
        self.index = index
    }
}

final class SequenceMessage {
    var from: SequenceParticipant
    var to: SequenceParticipant
    var label: String
    var arrowType: SequenceArrowType
    var number: Int
    init(from: SequenceParticipant, to: SequenceParticipant, label: String,
         arrowType: SequenceArrowType, number: Int) {
        self.from = from
        self.to = to
        self.label = label
        self.arrowType = arrowType
        self.number = number
    }
}

final class ParsedSequence {
    var participants: [SequenceParticipant] = []
    var messages: [SequenceMessage] = []
    var autonumber = false
    private var participantMap: [String: SequenceParticipant] = [:]

    func getParticipant(_ id: String) -> SequenceParticipant {
        if let p = participantMap[id] { return p }
        let p = SequenceParticipant(id: id, label: id, index: participants.count)
        participants.append(p)
        participantMap[id] = p
        return p
    }

    func lookup(_ id: String) -> SequenceParticipant? { participantMap[id] }

    func addParticipant(_ p: SequenceParticipant) {
        participants.append(p)
        participantMap[p.id] = p
    }
}

func isSequenceDiagram(_ input: String) -> Bool {
    for line in input.components(separatedBy: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("%%") { continue }
        return trimmed.hasPrefix(sequenceDiagramKeyword)
    }
    return false
}

/// Split on real or escaped newlines (diagram.SplitLines).
private func splitDiagramLines(_ input: String) -> [String] {
    let pattern = #"\n|\\n"#
    guard let re = try? NSRegularExpression(pattern: pattern) else { return [input] }
    let ns = input as NSString
    var result: [String] = []
    var last = 0
    re.enumerateMatches(in: input, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
        guard let m = match else { return }
        result.append(ns.substring(with: NSRange(location: last, length: m.range.location - last)))
        last = m.range.location + m.range.length
    }
    result.append(ns.substring(from: last))
    return result
}

/// diagram.RemoveComments: drop %% lines, strip inline %%, keep non-empty.
private func removeComments(_ lines: [String]) -> [String] {
    var cleaned: [String] = []
    for var line in lines {
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("%%") { continue }
        if let r = line.range(of: "%%") {
            line = String(line[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        if !line.trimmingCharacters(in: .whitespaces).isEmpty { cleaned.append(line) }
    }
    return cleaned
}

func parseSequence(_ input: String) throws -> ParsedSequence {
    let normalized = input
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
    let trimmedInput = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedInput.isEmpty { throw MermaidError.parseFailure("empty input") }

    let lines = removeComments(splitDiagramLines(trimmedInput))
    guard let first = lines.first,
          first.trimmingCharacters(in: .whitespaces).hasPrefix(sequenceDiagramKeyword) else {
        throw MermaidError.parseFailure("expected sequenceDiagram keyword")
    }

    let sd = ParsedSequence()
    for line in lines.dropFirst() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        if regexGroups(#"^\s*autonumber\s*$"#, trimmed) != nil {
            sd.autonumber = true
            continue
        }
        if try parseParticipant(trimmed, into: sd) { continue }
        if parseMessage(trimmed, into: sd) { continue }
        throw MermaidError.parseFailure("invalid syntax: \(trimmed)")
    }

    if sd.participants.isEmpty { throw MermaidError.parseFailure("no participants found") }
    return sd
}

private func parseParticipant(_ line: String, into sd: ParsedSequence) throws -> Bool {
    guard let m = regexGroups(#"^\s*participant\s+(?:"([^"]+)"|(\S+))(?:\s+as\s+(.+))?$"#, line) else {
        return false
    }
    var id = m[2]
    if !m[1].isEmpty { id = m[1] }
    var label = m[3]
    if label.isEmpty { label = id }
    label = label.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

    if sd.lookup(id) != nil { throw MermaidError.parseFailure("duplicate participant \(id)") }
    sd.addParticipant(SequenceParticipant(id: id, label: label, index: sd.participants.count))
    return true
}

private func parseMessage(_ line: String, into sd: ParsedSequence) -> Bool {
    guard let m = regexGroups(
        #"^\s*(?:"([^"]+)"|([^\s\->]+))\s*(-->>|->>)\s*(?:"([^"]+)"|([^\s\->]+))\s*:\s*(.*)$"#, line)
    else { return false }

    var fromID = m[2]
    if !m[1].isEmpty { fromID = m[1] }
    let arrow = m[3]
    var toID = m[5]
    if !m[4].isEmpty { toID = m[4] }
    let label = m[6].trimmingCharacters(in: .whitespaces)

    let from = sd.getParticipant(fromID)
    let to = sd.getParticipant(toID)
    let arrowType: SequenceArrowType = arrow == solidArrowSyntax ? .solid : .dotted
    let number = sd.autonumber ? sd.messages.count + 1 : 0
    sd.messages.append(SequenceMessage(from: from, to: to, label: label, arrowType: arrowType, number: number))
    return true
}
