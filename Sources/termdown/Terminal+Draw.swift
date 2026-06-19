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
    /// home, clear each line *before* overwriting it, then clear anything left
    /// below. `rows` must already be styled/truncated to width. This is what makes
    /// redraws flicker-free compared to `clearScreen()`.
    ///
    /// Both clears are positioned so they can never erase a cell of the frame —
    /// which matters because autowrap is disabled (`\e[?7l`) and so the cursor
    /// parks *on* the last column after a full-width row instead of advancing past
    /// it. So:
    ///   - The per-line clear (`\e[2K`) runs at the *start* of each line, never
    ///     after the row text; a trailing `\e[K` would erase that last column.
    ///   - The clear-below (`\e[J`) runs only when the frame is shorter than the
    ///     screen, after stepping onto the first blank line. When the frame fills
    ///     the screen the cursor would be on the bottom-right cell and `\e[J` would
    ///     erase it — dropping the corner of the border.
    /// tmux honors these edges strictly (borders vanished under tmux while iTerm2
    /// was forgiving), so getting them right is what keeps the frame sealed.
    static func render(_ rows: [String]) {
        write(frameSequence(rows, screenRows: size().rows))
    }

    /// Build the escape-sequence stream `render` writes. Pure (no I/O / size query)
    /// so the cursor/clear placement that keeps the frame sealed can be unit-tested.
    static func frameSequence(_ rows: [String], screenRows: Int) -> String {
        var buf = "\u{1B}[H"
        for (i, row) in rows.enumerated() {
            buf += "\u{1B}[2K" + row
            if i < rows.count - 1 { buf += "\r\n" }
        }
        if rows.count < screenRows { buf += "\r\n\u{1B}[J" }
        return buf
    }

    // SGR styling
    static func reverse(_ s: String) -> String { "\u{1B}[7m\(s)\u{1B}[0m" }
    static func bold(_ s: String) -> String { "\u{1B}[1m\(s)\u{1B}[0m" }
    static func dim(_ s: String) -> String { "\u{1B}[2m\(s)\u{1B}[0m" }
    static func cyan(_ s: String) -> String { "\u{1B}[36m\(s)\u{1B}[0m" }
    static func green(_ s: String) -> String { "\u{1B}[32m\(s)\u{1B}[0m" }
}
