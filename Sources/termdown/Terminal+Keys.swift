#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

extension Terminal {

    // MARK: - Key input

    enum Key: Equatable {
        case up, down, left, right
        case shiftUp, shiftDown   // Shift+Arrow (modified-arrow CSI; extends a selection)
        case pageUp, pageDown, home, end
        case enter
        case shiftEnter     // Shift+Enter (only on terminals that report it distinctly)
        case escape
        case backspace
        case tab, backTab
        case char(Character)
        case ctrlL          // force redraw
        case ctrlS          // save
        case mouseScroll(Int) // positive = down, negative = up
        case mouseClick(x: Int, y: Int) // left-button press at 1-based (col, row)
        case mouseDrag(x: Int, y: Int) // motion with the left button held
        case mouseRelease(x: Int, y: Int) // left-button release
        case other
    }

    /// Read a single logical key press, decoding common arrow-key and
    /// navigation escape sequences (arrows, Page Up/Down, Home/End).
    static func readKey() -> Key {
        readKey(timeoutMs: nil)!
    }

    /// Read a single logical key press with an optional timeout.
    /// Returns nil if timeout expires before a key is pressed.
    static func readKey(timeoutMs: Int32?) -> Key? {
        // A nil here means EOF (e.g. Ctrl-D or a closed stdin); treat as Escape
        // so callers exit cleanly instead of spinning.
        guard let b0 = readByte(timeoutMs: timeoutMs) else { return timeoutMs != nil ? nil : .escape }
        return decodeKey(first: b0, next: { readByte(timeoutMs: $0) })
    }

    /// Pure decoder: given the first byte `b0` and a `next` closure yielding
    /// subsequent bytes (taking the same poll timeout `readKey` uses, returning
    /// nil on timeout/EOF), decode one logical key. Kept free of stdin so the
    /// CSI/SS3/kitty/mouse parsing can be unit-tested by feeding byte arrays.
    static func decodeKey(first b0: UInt8, next: (Int32) -> UInt8?) -> Key {
        if b0 == 0x1B { // ESC
            // Peek for a CSI/SS3 sequence; if nothing follows quickly it's a bare ESC.
            guard let b1 = next(40) else { return .escape }
            if b1 == 0x5B /* [ */ || b1 == 0x4F /* O */ {
                guard let b2 = next(40) else { return .escape }
                switch b2 {
                case 0x3C /* < */:
                    // Mouse event in SGR mode: ESC [ < button ; x ; y M/m
                    var button = 0, x = 0, y = 0
                    var current = 0
                    var reading = 1 // 1 = button, 2 = x (col), 3 = y (row)
                    while let b = next(40) {
                        if b == 0x3B /* ; */ {
                            reading += 1
                            current = 0
                        } else if b == 0x4D /* M */ || b == 0x6D /* m */ {
                            let isPress = (b == 0x4D) // 'M' press, 'm' release
                            // The button field packs flags alongside the button
                            // number: bit 2 = Shift, 3 = Alt, 4 = Ctrl, 5 (32) =
                            // motion, 6 (64) = wheel. Mask them off so a drag
                            // (0|32) or a modified click still resolves to its
                            // button instead of falling through as `.other`.
                            let motion = (button & 32) != 0
                            let wheel = (button & 64) != 0
                            let btn = button & 3
                            if wheel && isPress { return .mouseScroll(btn == 0 ? -3 : 3) }
                            guard btn == 0 else { return .other }  // left button only
                            if motion { return .mouseDrag(x: x, y: y) }
                            return isPress ? .mouseClick(x: x, y: y) : .mouseRelease(x: x, y: y)
                        } else if b >= 0x30 && b <= 0x39 {
                            current = current * 10 + Int(b - 0x30)
                            switch reading {
                            case 1: button = current
                            case 2: x = current
                            default: y = current
                            }
                        } else {
                            break
                        }
                    }
                    return .other
                case 0x41: return .up
                case 0x42: return .down
                case 0x43: return .right
                case 0x44: return .left
                case 0x5A: return .backTab   // ESC [ Z  (Shift-Tab)
                case 0x48: return .home      // ESC [ H
                case 0x46: return .end       // ESC [ F
                case 0x30...0x39:
                    // Collect a full parameter list (semicolon-separated) up to the
                    // final byte, so multi-param sequences (modified keys) are consumed
                    // cleanly instead of leaking their tail bytes as stray keypresses.
                    var params: [Int] = []
                    var cur = Int(b2 - 0x30)
                    var finalByte: UInt8 = 0x7E
                    while let d = next(40) {
                        if d >= 0x30 && d <= 0x39 { cur = cur * 10 + Int(d - 0x30) }
                        else if d == 0x3B /* ; */ { params.append(cur); cur = 0 }
                        else { params.append(cur); finalByte = d; break }
                    }
                    if finalByte == 0x7E /* ~ */ {
                        // xterm modifyOtherKeys: ESC [ 27 ; <mod> ; <code> ~
                        if params.count == 3 && params[0] == 27 {
                            if params[2] == 13 { return params[1] == 2 ? .shiftEnter : .enter }
                            return .other
                        }
                        switch params.first ?? 0 {
                        case 1, 7: return .home
                        case 4, 8: return .end
                        case 5: return .pageUp
                        case 6: return .pageDown
                        default: return .other
                        }
                    }
                    if finalByte == 0x75 /* u */ {
                        // kitty keyboard protocol: ESC [ <code> ; <mod> u
                        if params.first == 13 {
                            return (params.count > 1 && params[1] == 2) ? .shiftEnter : .enter
                        }
                        return .other
                    }
                    // Modified arrows: ESC [ 1 ; <mod> A/B/C/D  (mod 2 = Shift).
                    if params.count >= 2, params[0] == 1 {
                        let shift = params[1] == 2
                        switch finalByte {
                        case 0x41: return shift ? .shiftUp : .up
                        case 0x42: return shift ? .shiftDown : .down
                        case 0x43: return .right
                        case 0x44: return .left
                        default: break
                        }
                    }
                    return .other
                default: return .other
                }
            }
            return .escape
        }

        switch b0 {
        case 0x0D, 0x0A: return .enter
        case 0x09: return .tab
        // Ctrl-C is delivered as SIGINT (ISIG stays enabled in raw mode) and
        // handled by the signal handler, so byte 0x03 never reaches here. It must
        // NOT be decoded as the letter "c" — that would make a typed "c"
        // indistinguishable from Ctrl-C. It falls through to `.other` below.
        case 0x0C: return .ctrlL     // Ctrl-L
        case 0x13: return .ctrlS     // Ctrl-S (IXON is disabled, so this reaches us)
        case 0x7F, 0x08: return .backspace
        default:
            if b0 >= 0x20 && b0 < 0x7F {
                return .char(Character(UnicodeScalar(b0)))
            }
            return .other
        }
    }

    /// Read one raw byte from stdin. When `timeoutMs` is provided, returns nil if
    /// no byte arrives within that window (used to disambiguate escape sequences).
    private static func readByte(timeoutMs: Int32? = nil) -> UInt8? {
        if let t = timeoutMs {
            var fds = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
            let r = poll(&fds, 1, t)
            if r <= 0 { return nil }
        }
        var byte: UInt8 = 0
        let n = read(STDIN_FILENO, &byte, 1)
        return n == 1 ? byte : nil
    }
}
