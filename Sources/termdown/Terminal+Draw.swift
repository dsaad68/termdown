import Foundation
import termdownCore
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

extension Terminal {

    // MARK: - ANSI output helpers

    static func write(_ s: String) {
        FileHandle.standardOutput.write(Data(s.utf8))
    }

    /// Copy `text` to the system clipboard. Emits OSC 52 (works over SSH and
    /// tmux passthrough) and, on macOS, also pipes to `pbcopy` as a fallback for
    /// terminals — notably Apple Terminal — that don't implement OSC 52.
    static func copyToClipboard(_ text: String) {
        write(Ansi.osc52(text))
        #if canImport(Darwin)
        let pb = "/usr/bin/pbcopy"
        if FileManager.default.isExecutableFile(atPath: pb) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: pb)
            let pipe = Pipe()
            proc.standardInput = pipe
            if (try? proc.run()) != nil {
                pipe.fileHandleForWriting.write(Data(text.utf8))
                try? pipe.fileHandleForWriting.close()
                proc.waitUntilExit()
            }
        }
        #endif
    }

    static func clearScreen() { write("\u{1B}[2J\u{1B}[H") }
    static func moveHome() { write("\u{1B}[H") }
    static func moveCursor(row: Int, col: Int) { write("\u{1B}[\(row);\(col)H") }
    static func hideCursor() { write("\u{1B}[?25l") }
    static func showCursor() { write("\u{1B}[?25h") }
    static func clearLine() { write("\u{1B}[2K") }

    /// Paint a full frame without the flash of a screen clear: move the cursor
    /// home, overwrite each row (clearing to end-of-line as we go), then clear
    /// anything left below. `rows` must already be styled/truncated to width.
    /// This is what makes redraws flicker-free compared to `clearScreen()`.
    static func render(_ rows: [String]) {
        var buf = "\u{1B}[H"
        for (i, row) in rows.enumerated() {
            buf += row + "\u{1B}[K"
            if i < rows.count - 1 { buf += "\r\n" }
        }
        buf += "\u{1B}[J"
        write(buf)
    }

    // SGR styling
    static func reverse(_ s: String) -> String { "\u{1B}[7m\(s)\u{1B}[0m" }
    static func bold(_ s: String) -> String { "\u{1B}[1m\(s)\u{1B}[0m" }
    static func dim(_ s: String) -> String { "\u{1B}[2m\(s)\u{1B}[0m" }
    static func cyan(_ s: String) -> String { "\u{1B}[36m\(s)\u{1B}[0m" }
    static func green(_ s: String) -> String { "\u{1B}[32m\(s)\u{1B}[0m" }
}
