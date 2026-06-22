import XCTest
@testable import MermaidRenderer

/// Fidelity tests: render each upstream mermaid-ascii testdata fixture and
/// compare byte-for-byte against its committed golden. Fixtures live under
/// Tests/MermaidRendererTests/testdata, copied verbatim from the mermaid-ascii
/// repo (MIT). `ascii/` and `multibyte/` use the ASCII charset; `extended-chars/`
/// uses Unicode — matching the upstream graph_test.go harness.
final class MermaidGoldenTests: XCTestCase {
    private struct GoldenCase {
        var mermaid: String
        var expected: String
        var paddingX: Int
        var paddingY: Int
    }

    private var testdataDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("testdata")
    }

    func testAsciiGoldens() throws {
        try runDirectory("ascii", useAscii: true)
    }

    func testExtendedCharsGoldens() throws {
        try runDirectory("extended-chars", useAscii: false)
    }

    func testMultibyteGoldens() throws {
        try runDirectory("multibyte", useAscii: true)
    }

    // MARK: - Harness

    private func runDirectory(_ name: String, useAscii: Bool) throws {
        let dir = testdataDir.appendingPathComponent(name)
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "txt" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        XCTAssertFalse(files.isEmpty, "No testdata fixtures found in \(name)")

        var failures: [String] = []
        for file in files {
            let tc = try readTestCase(file)
            let actual = render(tc, useAscii: useAscii)
            if actual != tc.expected {
                failures.append("""
                ✗ \(name)/\(file.lastPathComponent)
                --- expected ---
                \(visualize(tc.expected))
                --- actual ---
                \(visualize(actual))
                """)
            }
        }
        if !failures.isEmpty {
            XCTFail("\(failures.count)/\(files.count) fixtures failed in \(name):\n\n"
                + failures.joined(separator: "\n\n"))
        }
    }

    private func render(_ tc: GoldenCase, useAscii: Bool) -> String {
        guard let properties = try? mermaidFileToMap(tc.mermaid, styleType: "cli") else {
            return "<<parse error>>"
        }
        properties.paddingX = tc.paddingX
        properties.paddingY = tc.paddingY
        properties.useAscii = useAscii
        return drawMap(properties, colorEnabled: false)
    }

    /// Port of testutil.ReadTestCase.
    private func readTestCase(_ url: URL) throws -> GoldenCase {
        var content = try String(contentsOf: url, encoding: .utf8)
        if content.hasSuffix("\n") { content.removeLast() } // emulate bufio.Scanner
        let lines = content.components(separatedBy: "\n")

        var paddingX = 5
        var paddingY = 5
        var mermaid: [String] = []
        var expected: [String] = []
        var inMermaid = true
        var mermaidStarted = false

        for line in lines {
            if line == "---" {
                inMermaid = false
                continue
            }
            if inMermaid {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !mermaidStarted {
                    if trimmed.isEmpty { continue }
                    if let m = regexGroups(#"^(?i)(padding[xy])\s*=\s*(\d+)\s*$"#, trimmed), let v = Int(m[2]) {
                        if m[1].lowercased() == "paddingx" { paddingX = v } else { paddingY = v }
                        continue
                    }
                }
                mermaidStarted = true
                mermaid.append(line)
            } else {
                expected.append(line)
            }
        }

        return GoldenCase(
            mermaid: mermaid.map { $0 + "\n" }.joined(),
            expected: expected.joined(separator: "\n"),
            paddingX: paddingX,
            paddingY: paddingY)
    }

    private func visualize(_ s: String) -> String {
        s.replacingOccurrences(of: " ", with: "·")
    }
}
