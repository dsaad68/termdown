import termdownCore

/// A curated set of viewer (pager) actions that can be rebound from config via
/// `key-<action>: <char>`. Rebinding is a thin translation layer: a configured
/// key is mapped to the action's canonical key, which the existing input switch
/// already handles — so an override *adds* a key for that action (the default key
/// keeps working too). Text-entry contexts (search, goto, the fuzzy file list)
/// are deliberately not remapped.
enum KeyBindings {

    /// Action name → canonical (default) key. Only single-character keys are
    /// rebindable; arrows / Enter / Tab / Backspace are fixed.
    static let defaults: [String: Character] = [
        "scroll-down": "j", "scroll-up": "k",
        "page-down": "f", "page-up": "b",
        "half-down": "d", "half-up": "u",
        "top": "g", "bottom": "G",
        "search": "/", "next-match": "n", "prev-match": "N",
        "project-search": "\\",
        "open-link": "o", "new-tab": "T", "theme": "p",
        "sidebar": "s", "wrap": "w", "follow": "F", "banner": "B",
        "fold": "z", "fold-all": "Z",
        "next-heading": "]", "prev-heading": "[",
        "edit": "e", "cursor": "v",
        "contents": "t", "help": "?", "quit": "q",
    ]

    /// Build a `userKey → canonicalKey` translation from config overrides. Only
    /// known actions bound to a single character are honored; a binding to the
    /// action's own default key is a no-op.
    static func translation(from overrides: [String: String]?) -> [Character: Character] {
        guard let overrides = overrides else { return [:] }
        var map: [Character: Character] = [:]
        for (action, keyStr) in overrides {
            guard keyStr.count == 1, let key = keyStr.first,
                  let canonical = defaults[action], key != canonical else { continue }
            map[key] = canonical
        }
        return map
    }
}
