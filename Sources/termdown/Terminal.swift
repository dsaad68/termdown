import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Low-level terminal control: raw mode, mouse tracking, the alternate screen,
/// cleanup hooks and window-size queries. Key reading, drawing primitives,
/// overlays, animations and help text live in the `Terminal+*` extensions.
enum Terminal {

    // MARK: - Raw mode

    private static var savedTermios: termios?

    /// Set by the `SIGWINCH` handler; the UI loops poll this to reflow on resize.
    static var didResize = false

    /// Set by `FolderWatcher`'s FSEvents callback when the watched directory's
    /// contents change; the picker polls this to refresh its file list.
    static var folderChanged = false

    private static var altScreenActive = false

    /// Switch the terminal into raw (cbreak) mode: no echo, no line buffering.
    /// `ISIG` is left enabled so Ctrl-C still works; we restore on exit via a
    /// signal handler installed in `installCleanup()`.
    static func enableRawMode() {
        var raw = termios()
        guard tcgetattr(STDIN_FILENO, &raw) == 0 else { return }
        if savedTermios == nil { savedTermios = raw }

        raw.c_lflag &= ~tcflag_t(ECHO | ICANON)
        raw.c_iflag &= ~tcflag_t(ICRNL | IXON)

        // VMIN = 1, VTIME = 0 -> blocking read of at least one byte.
        withUnsafeMutablePointer(to: &raw.c_cc) { ptr in
            ptr.withMemoryRebound(to: cc_t.self, capacity: Int(NCCS)) { cc in
                cc[Int(VMIN)] = 1
                cc[Int(VTIME)] = 0
            }
        }
        _ = tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
    }

    /// Restore the terminal to the mode captured before `enableRawMode()`.
    static func disableRawMode() {
        guard var saved = savedTermios else { return }
        _ = tcsetattr(STDIN_FILENO, TCSAFLUSH, &saved)
        forceDisableMouseTracking()
    }

    // MARK: - Mouse tracking

    /// One entry per active `enableMouseTracking` scope, holding whether that
    /// scope asked for drag reporting.
    ///
    /// A stack rather than a flag because UIs nest: the file finder opened from
    /// inside the pager (`T`) used to hit the idempotence guard on the way in and
    /// then unconditionally tear tracking down on the way out, leaving the still
    /// running pager with the mouse dead for the rest of the session.
    private static var mouseScopes: [Bool] = []

    /// Number of active tracking scopes — lets tests assert that nesting balances.
    static var mouseTrackingDepth: Int { mouseScopes.count }

    /// Enable mouse tracking for scroll events (SGR mode). With `drag`, also turn
    /// on button-event tracking (`?1002h`) so motion is reported while a button is
    /// held — what drag-to-select needs. `?1003h` (any motion) would report every
    /// pointer move and is deliberately not used.
    ///
    /// Motion tracking takes click-drag away from the terminal's own text
    /// selection, so it stays behind the opt-in `mouse-select` setting.
    ///
    /// Every call must be balanced by exactly one `disableMouseTracking()`.
    static func enableMouseTracking(drag: Bool = false) {
        let wasActive = !mouseScopes.isEmpty
        let hadDrag = mouseScopes.contains(true)
        mouseScopes.append(drag)
        if !wasActive {
            write("\u{1B}[?1000h") // Enable mouse tracking
            write("\u{1B}[?1006h") // Enable SGR mode for better coordinates
        }
        // Report motion while a button is held.
        if drag, !hadDrag { write("\u{1B}[?1002h") }
    }

    /// Leave one tracking scope. Modes are only turned off once the last scope
    /// that wanted them is gone, so an inner UI exiting leaves an outer one's
    /// tracking intact.
    static func disableMouseTracking() {
        guard !mouseScopes.isEmpty else { return }
        let hadDrag = mouseScopes.contains(true)
        mouseScopes.removeLast()
        if hadDrag, !mouseScopes.contains(true) {
            write("\u{1B}[?1002l") // Disable button-event (drag) tracking
        }
        if mouseScopes.isEmpty {
            write("\u{1B}[?1006l") // Disable SGR mode
            write("\u{1B}[?1000l") // Disable mouse tracking
        }
    }

    /// Tear tracking down regardless of depth. Used by the exit paths only —
    /// `disableRawMode()`, which the atexit hook and the SIGINT/SIGTERM handlers
    /// call. Those unwind the process, not a UI scope, so a non-zero depth there
    /// would leak `?1000h` into the user's shell.
    static func forceDisableMouseTracking() {
        guard !mouseScopes.isEmpty else { return }
        mouseScopes.removeAll()
        write("\u{1B}[?1006l")
        write("\u{1B}[?1002l")
        write("\u{1B}[?1000l")
    }

    // MARK: - Alternate screen

    /// Switch to the alternate screen buffer (like `less`/`vim`) so the user's
    /// scrollback is preserved and restored on exit.
    ///
    /// We also disable autowrap (DECAWM, `?7l`). The full-screen UI positions
    /// every cell explicitly and draws exactly `size.rows` lines per frame; if a
    /// row's computed width is ever one column over the terminal width — e.g. an
    /// emoji like ✅ (U+2705) that a terminal renders double-width but Unicode
    /// tables call single-width — autowrap would push that row onto a second
    /// physical line, scroll the screen, and desync every later `\e[H` redraw.
    /// That showed up as scrolling "breaking" inside a tmux popup (its 90% width
    /// lands on the off-by-one boundary). With autowrap off the overflow is
    /// clipped at the right margin instead and the frame stays aligned. This also
    /// avoids the classic scroll glitch from writing the bottom-right cell.
    static func enterAltScreen() {
        if altScreenActive { return }
        write("\u{1B}[?1049h\u{1B}[?7l")
        altScreenActive = true
    }

    /// Return to the primary screen buffer, restoring the user's prior contents
    /// and re-enabling autowrap.
    static func exitAltScreen() {
        if !altScreenActive { return }
        write("\u{1B}[?7h\u{1B}[?1049l")
        altScreenActive = false
    }

    /// Install signal handlers / atexit hooks so the terminal is always restored
    /// and the cursor made visible, even on Ctrl-C or abnormal exit.
    static func installCleanup() {
        atexit {
            Terminal.showCursor()
            Terminal.exitAltScreen()
            Terminal.disableRawMode()
            FolderWatcher.stop()
        }
        for sig in [SIGINT, SIGTERM] {
            signal(sig) { _ in
                // Only restore state with an effect that outlives the process (the
                // terminal mode/screen). FSEventStream teardown isn't safe to call
                // from a signal handler (it's not async-signal-safe) and isn't
                // needed here: `_exit` tears the whole process down immediately, so
                // its background queue and kqueue fd go away with it regardless.
                Terminal.showCursor()
                Terminal.exitAltScreen()
                Terminal.disableRawMode()
                _exit(0)
            }
        }
        // Note when the window is resized so UI loops can reflow.
        signal(SIGWINCH) { _ in Terminal.didResize = true }
    }

    // MARK: - Size

    struct Size {
        var rows: Int
        var cols: Int
        var widthPx: Int
        var heightPx: Int
    }

    /// Query the terminal window size in cells and (when available) pixels.
    static func size() -> Size {
        var ws = winsize()
        let ok = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws) == 0
        var rows = ok ? Int(ws.ws_row) : 0
        var cols = ok ? Int(ws.ws_col) : 0
        if rows <= 0 { rows = 24 }
        if cols <= 0 { cols = 80 }
        let widthPx = Int(ws.ws_xpixel)
        let heightPx = Int(ws.ws_ypixel)
        return Size(rows: rows, cols: cols, widthPx: widthPx, heightPx: heightPx)
    }
}
