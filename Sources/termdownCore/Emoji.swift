import Foundation

/// Converts GitHub-style `:shortcode:` emoji into their Unicode glyphs.
///
/// Only a curated set of common shortcodes is supported; unrecognized `:tokens:`
/// are left exactly as written. Substitution is applied to plain inline text only
/// (the inline flattener calls it on `Text` runs), so code spans — a separate AST
/// node — are never touched, and `:34:`-style time/ratio text passes through
/// because those names aren't in the table.
public enum Emoji {

    /// Replace every recognized `:name:` shortcode in `text` with its emoji glyph.
    public static func substitute(_ text: String) -> String {
        guard text.contains(":") else { return text }
        let chars = Array(text)
        let n = chars.count
        var out = ""
        var i = 0
        while i < n {
            if chars[i] == ":" {
                // Scan a bounded shortcode token up to the next colon.
                var j = i + 1
                while j < n, chars[j] != ":", isShortcodeChar(chars[j]) { j += 1 }
                if j < n, chars[j] == ":", j > i + 1, let glyph = map[String(chars[(i + 1)..<j])] {
                    out += glyph
                    i = j + 1
                    continue
                }
            }
            out.append(chars[i])
            i += 1
        }
        return out
    }

    private static func isShortcodeChar(_ c: Character) -> Bool {
        c.isASCII && (c.isLetter || c.isNumber || c == "_" || c == "+" || c == "-")
    }

    /// Common GFM shortcodes. Intentionally curated, not exhaustive.
    static let map: [String: String] = [
        // Reactions / hands
        "+1": "👍", "thumbsup": "👍", "-1": "👎", "thumbsdown": "👎",
        "ok_hand": "👌", "wave": "👋", "clap": "👏", "raised_hands": "🙌",
        "pray": "🙏", "muscle": "💪", "point_up": "☝️", "point_right": "👉",
        "point_left": "👈", "point_down": "👇", "fist": "✊", "v": "✌️",
        "handshake": "🤝", "writing_hand": "✍️",
        // Faces
        "smile": "😄", "smiley": "😃", "grin": "😁", "laughing": "😆",
        "joy": "😂", "rofl": "🤣", "blush": "😊", "slight_smile": "🙂",
        "wink": "😉", "heart_eyes": "😍", "kissing_heart": "😘",
        "thinking": "🤔", "neutral_face": "😐", "expressionless": "😑",
        "unamused": "😒", "sweat_smile": "😅", "sob": "😭", "cry": "😢",
        "rage": "😡", "angry": "😠", "scream": "😱", "fearful": "😨",
        "flushed": "😳", "sunglasses": "😎", "sleeping": "😴",
        "nerd_face": "🤓", "exploding_head": "🤯", "shushing_face": "🤫",
        "raised_eyebrow": "🤨", "smirk": "😏", "grimacing": "😬",
        "yum": "😋", "stuck_out_tongue": "😛", "zany_face": "🤪",
        // Hearts / symbols
        "heart": "❤️", "yellow_heart": "💛", "green_heart": "💚",
        "blue_heart": "💙", "purple_heart": "💜", "broken_heart": "💔",
        "sparkling_heart": "💖", "star": "⭐", "star2": "🌟", "sparkles": "✨",
        "zap": "⚡", "fire": "🔥", "boom": "💥", "100": "💯", "dizzy": "💫",
        "exclamation": "❗", "question": "❓", "bangbang": "‼️",
        // Check / status
        "white_check_mark": "✅", "heavy_check_mark": "✔️", "x": "❌",
        "negative_squared_cross_mark": "❎", "warning": "⚠️", "no_entry": "⛔",
        "no_entry_sign": "🚫", "heavy_plus_sign": "➕", "heavy_minus_sign": "➖",
        "heavy_multiplication_x": "✖️", "recycle": "♻️", "white_circle": "⚪",
        "red_circle": "🔴", "large_blue_circle": "🔵", "green_circle": "🟢",
        "yellow_circle": "🟡", "orange_circle": "🟠",
        // Arrows
        "arrow_right": "➡️", "arrow_left": "⬅️", "arrow_up": "⬆️",
        "arrow_down": "⬇️", "arrow_forward": "▶️", "rewind": "◀️",
        // Objects / dev
        "rocket": "🚀", "tada": "🎉", "confetti_ball": "🎊", "gift": "🎁",
        "bulb": "💡", "wrench": "🔧", "hammer": "🔨", "gear": "⚙️",
        "lock": "🔒", "unlock": "🔓", "key": "🔑", "mag": "🔍",
        "link": "🔗", "paperclip": "📎", "pushpin": "📌", "pencil2": "✏️",
        "memo": "📝", "books": "📚", "book": "📖", "bookmark": "🔖",
        "clipboard": "📋", "calendar": "📅", "chart_with_upwards_trend": "📈",
        "chart_with_downwards_trend": "📉", "bar_chart": "📊",
        "computer": "💻", "keyboard": "⌨️", "iphone": "📱", "battery": "🔋",
        "bug": "🐛", "construction": "🚧", "package": "📦", "label": "🏷️",
        "calling": "📲", "envelope": "✉️", "email": "📧", "inbox_tray": "📥",
        "outbox_tray": "📤", "floppy_disk": "💾", "cd": "💿", "printer": "🖨️",
        "telescope": "🔭", "microscope": "🔬", "test_tube": "🧪",
        "satellite": "🛰️", "globe_with_meridians": "🌐", "hourglass": "⌛",
        "alarm_clock": "⏰", "stopwatch": "⏱️", "watch": "⌚", "bell": "🔔",
        "no_bell": "🔕", "mega": "📣", "loudspeaker": "📢", "speech_balloon": "💬",
        "thought_balloon": "💭", "hammer_and_wrench": "🛠️", "shield": "🛡️",
        "card_file_box": "🗃️", "wastebasket": "🗑️", "scroll": "📜",
        "page_facing_up": "📄", "open_file_folder": "📂", "file_folder": "📁",
        // Nature / misc
        "sunny": "☀️", "cloud": "☁️", "snowflake": "❄️", "umbrella": "☔",
        "ocean": "🌊", "earth_americas": "🌎", "moon": "🌙", "rainbow": "🌈",
        "deciduous_tree": "🌳", "seedling": "🌱", "herb": "🌿", "leaves": "🍃",
        "four_leaf_clover": "🍀", "cactus": "🌵", "mushroom": "🍄",
        // Food / drink
        "coffee": "☕", "tea": "🍵", "beer": "🍺", "pizza": "🍕",
        "hamburger": "🍔", "cake": "🍰", "birthday": "🎂", "cookie": "🍪",
        "apple": "🍎", "lemon": "🍋", "watermelon": "🍉", "hot_pepper": "🌶️",
        // Animals
        "dog": "🐶", "cat": "🐱", "mouse": "🐭", "fox_face": "🦊",
        "bear": "🐻", "panda_face": "🐼", "penguin": "🐧", "bird": "🐦",
        "snake": "🐍", "turtle": "🐢", "whale": "🐳", "dolphin": "🐬",
        "ant": "🐜", "honeybee": "🐝", "beetle": "🪲", "unicorn": "🦄",
        // Flags / awards
        "checkered_flag": "🏁", "triangular_flag_on_post": "🚩",
        "trophy": "🏆", "medal": "🏅", "1st_place_medal": "🥇",
        "2nd_place_medal": "🥈", "3rd_place_medal": "🥉", "dart": "🎯",
        // People-ish / status
        "eyes": "👀", "skull": "💀", "ghost": "👻", "alien": "👽",
        "robot": "🤖", "poop": "💩", "crown": "👑", "gem": "💎",
        "moneybag": "💰", "dollar": "💵", "hot": "🥵", "cold": "🥶",
    ]
}
