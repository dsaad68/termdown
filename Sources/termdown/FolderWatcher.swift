import Foundation
#if canImport(CoreServices)
import CoreServices
#endif

/// Watches a directory tree for filesystem changes (files added, removed, or
/// renamed) via FSEvents and sets `Terminal.folderChanged` so the UI loops
/// know to re-scan. macOS-only; a no-op everywhere else so Linux still builds
/// and tests (CI runs both).
enum FolderWatcher {
    #if canImport(CoreServices)
    private static var stream: FSEventStreamRef?
    #endif

    /// Begin watching `root` recursively. Safe to call once at startup; a
    /// second call while already watching is a no-op.
    static func start(root: URL) {
        #if canImport(CoreServices)
        guard stream == nil else { return }
        var context = FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, _, _, _, _, _ in
            Terminal.folderChanged = true
        }
        let pathsToWatch = [root.path] as CFArray
        guard let s = FSEventStreamCreate(
            kCFAllocatorDefault, callback, &context, pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,  // latency: coalesce bursts of writes into one callback
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer)
        ) else { return }
        stream = s
        FSEventStreamSetDispatchQueue(s, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(s)
        #endif
    }

    static func stop() {
        #if canImport(CoreServices)
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        stream = nil
        #endif
    }
}
