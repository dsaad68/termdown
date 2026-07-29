import Foundation

/// What termdown will actually do, once the command line, the config file and
/// the filesystem have all had their say.
///
/// Replaces an arrangement where the outcome was *inferred* from which of
/// `directory`/`renderFile`/`useStdin` happened to be set, and where turning a
/// bare path into a render rewrote one field into another — destroying the
/// evidence of what the user had actually typed.
enum ResolvedAction: Equatable {
    case picker(root: String)
    case view(file: String)
    case render(file: String)
    case stdin
}

/// What a path is, as far as this decision cares. Supplied to the resolver as a
/// closure so the resolver stays a pure function that tests drive without
/// touching disk.
enum PathKind: Equatable {
    case missing
    case directory
    case file

    /// The only impure part: the real filesystem.
    static func of(_ path: String) -> PathKind {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return .missing }
        return isDirectory.boolValue ? .directory : .file
    }
}

enum ActionResolver {
    enum Outcome: Equatable {
        case action(ResolvedAction)
        case failure(message: String, code: Int32)
    }

    /// Decide what to do.
    ///
    /// - `bareRender` only ever changes what a *bare* path means; an action named
    ///   outright on the command line is not up for reinterpretation.
    /// - `stdinIsTTY == false` with no path at all means a document was piped in.
    ///   A path on the command line still beats the pipe.
    static func resolve(_ requested: RequestedAction,
                        bareRender: Bool,
                        stdinIsTTY: Bool,
                        cwd: String,
                        kind: (String) -> PathKind) -> Outcome {
        switch requested {
        case .stdin:
            return .action(.stdin)

        case .render(let path):
            // Existence is not checked here: the reader reports `cannot read`,
            // which also covers a file that exists but cannot be opened.
            return .action(.render(file: path))

        case .open(let path):
            // Asking to open a folder is asking for the picker — that is the
            // only interactive thing a directory can mean.
            switch kind(path) {
            case .missing:   return .failure(message: noSuchFile(path), code: 1)
            case .directory: return .action(.picker(root: path))
            case .file:      return .action(.view(file: path))
            }

        case .bare(nil):
            return .action(stdinIsTTY ? .picker(root: cwd) : .stdin)

        case .bare(.some(let path)):
            switch kind(path) {
            case .missing:
                return .failure(message: noSuchFile(path), code: 1)
            case .directory:
                return .action(.picker(root: path))
            case .file:
                // The one thing `bare-render` decides.
                return .action(bareRender ? .render(file: path) : .view(file: path))
            }
        }
    }

    private static func noSuchFile(_ path: String) -> String {
        "termdown: '\(path)': no such file or directory"
    }
}
