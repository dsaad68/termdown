import Foundation
import termdownCore

// The file picker's secondary (mtime) column. Pure helpers, so they live here
// rather than in : globals declared there are bound to top-level
// program execution and are unsafe to touch from another file, but these take
// everything they need as parameters.

/// Short, human-friendly modification time for the picker's secondary column.
func relativeDate(_ date: Date) -> String {
    let secs = Date().timeIntervalSince(date)
    if secs < 60 { return "now" }
    if secs < 3600 { return "\(Int(secs / 60))m" }
    if secs < 86400 { return "\(Int(secs / 3600))h" }
    if secs < 7 * 86400 { return "\(Int(secs / 86400))d" }
    let fmt = DateFormatter()
    fmt.dateFormat = "MMM d"
    return fmt.string(from: date)
}

func fileDetails(_ entries: [FileScanner.Entry]) -> [String] {
    entries.map { entry -> String in
        let attrs = try? FileManager.default.attributesOfItem(atPath: entry.url.path)
        guard let date = attrs?[.modificationDate] as? Date else { return "" }
        return relativeDate(date)
    }
}
