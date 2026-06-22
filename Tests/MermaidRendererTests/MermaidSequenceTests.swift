import XCTest
@testable import MermaidRenderer

/// Sequence-diagram fidelity tests. Upstream compares with whitespace
/// normalization (trailing spaces / blank edge lines ignored), so we do too.
/// `sequence/` goldens are Unicode, `sequence-ascii/` are ASCII.
final class MermaidSequenceTests: XCTestCase {
    private var testdataDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("testdata")
    }

    func testSequenceUnicodeGoldens() throws {
        try runDirectory("sequence", useAscii: false)
    }

    func testSequenceAsciiGoldens() throws {
        try runDirectory("sequence-ascii", useAscii: true)
    }

    private func runDirectory(_ name: String, useAscii: Bool) throws {
        let dir = testdataDir.appendingPathComponent(name)
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "txt" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertFalse(files.isEmpty, "No sequence fixtures in \(name)")

        var failures: [String] = []
        for file in files {
            guard let (mermaid, expected) = readSequenceTestCase(file) else {
                failures.append("✗ \(name)/\(file.lastPathComponent): malformed test case")
                continue
            }
            guard let sd = try? parseSequence(mermaid) else {
                failures.append("✗ \(name)/\(file.lastPathComponent): parse failed")
                continue
            }
            let actual = normalizeWhitespace(renderSequenceDiagram(sd, useAscii: useAscii))
            if actual != normalizeWhitespace(expected) {
                failures.append("""
                ✗ \(name)/\(file.lastPathComponent)
                --- expected ---
                \(expected)
                --- actual ---
                \(actual)
                """)
            }
        }
        if !failures.isEmpty {
            XCTFail("\(failures.count)/\(files.count) sequence fixtures failed in \(name):\n\n"
                + failures.joined(separator: "\n\n"))
        }
    }

    /// Port of testutil.ReadSequenceTestCase (split on "\n---\n").
    private func readSequenceTestCase(_ url: URL) -> (String, String)? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let parts = content.components(separatedBy: "\n---\n")
        guard parts.count == 2 else { return nil }
        return (
            parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
            parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// Port of testutil.NormalizeWhitespace.
    private func normalizeWhitespace(_ s: String) -> String {
        var normalized: [String] = []
        for line in s.components(separatedBy: "\n") {
            var end = line.endIndex
            while end > line.startIndex, line[line.index(before: end)] == " " {
                end = line.index(before: end)
            }
            let trimmed = String(line[..<end])
            if !trimmed.isEmpty || !normalized.isEmpty { normalized.append(trimmed) }
        }
        while let last = normalized.last, last.isEmpty { normalized.removeLast() }
        return normalized.joined(separator: "\n")
    }
}
