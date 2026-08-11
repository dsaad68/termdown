import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import termdownCore

/// The settings every entry point needs, assembled once in `main.swift` and
/// passed down rather than reached for as globals.
struct AppEnvironment {
    var width: Int?
    var mouseEnabled: Bool
    var mouseSelectEnabled: Bool
    var keyTranslation: [Character: Character]
    var ignorePatterns: [String]
    /// Which list the picker opens on (config `file-list-view`). `d` switches at
    /// any time, so this is only the starting point.
    var fileListView: MenuList.Mode = .files
    let render: RenderContext
}

/// Run `body` with the terminal in raw mode on the alternate screen, restoring
/// it on the way out.
///
/// Both halves are needed: `defer` covers a normal return, `installCleanup`
/// covers what it cannot — SIGINT, SIGTERM and `exit`. This has to live in a
/// file of its own, because a `defer` written at `main.swift`'s top level does
/// not scope the way it looks like it does.
func withTerminalUI(_ body: () -> Void) {
    Terminal.installCleanup()
    Terminal.enableRawMode()
    Terminal.enterAltScreen()
    defer {
        Terminal.exitAltScreen()
        Terminal.disableRawMode()
        Terminal.showCursor()
    }
    body()
}

/// `termdown -`: page the piped document when stdout is a terminal, print it
/// plain when it is not — so `termdown -` and `… | termdown - > out.txt` both
/// do the useful thing.
func runStdin(env: AppEnvironment) {
    let source = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""

    guard isatty(STDOUT_FILENO) != 0 else {
        let width = env.width ?? Terminal.size().cols
        print(env.render.render(source, width: width).lines.joined(separator: "\n"))
        return
    }

    withTerminalUI {
        var pager = Pager(title: "stdin", lines: [])
        pager.fixedWidth = env.width
        pager.mouseEnabled = env.mouseEnabled
        pager.mouseSelectEnabled = env.mouseSelectEnabled
        pager.renderSource = { env.render.render(source, width: $0) }
        pager.keyTranslation = env.keyTranslation
        pager.onToggleHeadingBanners = { env.render.headingBanners = $0 }
        // A piped document has no folder session, but the settings view needs
        // nothing from one — only the render context a live change lands on.
        pager.onSettings = {
            var settings = ConfigMenu(hooks: ConfigMenu.Hooks(
                applyRenderSetting: { env.render.apply($0, value: $1) }))
            settings.run()
        }
        pager.run()
    }
}

/// Render one file to stdout and exit. Never interactive, whatever stdout is —
/// asking for a render is asking for text, not a pager.
func renderToStdout(_ path: String, env: AppEnvironment) -> Never {
    let url = URL(fileURLWithPath: path).standardizedFileURL
    guard let source = try? String(contentsOf: url, encoding: .utf8) else {
        FileHandle.standardError.write(Data("termdown: cannot read \(url.path)\n".utf8))
        exit(1)
    }
    let width = env.width ?? Terminal.size().cols
    print(env.render.render(source, width: width).lines.joined(separator: "\n"))
    exit(0)
}
