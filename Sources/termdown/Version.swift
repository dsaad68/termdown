/// The termdown release version.
///
/// This is the single source of truth used by both `--version` and the file-list
/// window header. The release workflow (`.github/workflows/release.yml`) verifies
/// that this string matches the pushed `v*` git tag before publishing, so a tag of
/// `v0.1.1` must correspond to `appVersion = "0.1.1"` here.
///
/// Kept in its own file (not `main.swift`): globals declared in an executable's
/// `main.swift` are bound to top-level program execution, so referencing them from
/// other files — including under `@testable import` — is unsafe. The name is
/// `appVersion` (not `version`) to avoid `NSObject`'s inherited static `version`.
let appVersion = "0.1.2"
