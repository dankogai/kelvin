// modules/SION.k - SION values, parsed from text and written back (#152):
// SION, Swift Interchangeable Object Notation, is JSON with more, as Dan
// Kogai's https://dankogai.github.io/SION/ has it: nil, bool, an integer
// and a double apart, a string, data (a binary blob), a date, an ext (a
// MessagePack extension), an array, and a dictionary keyed by any value;
// comments run from // to the end of the line.
//
//     #import <SION>
//     var s = SION.parse("""
//         [ "name": "kelvin", "tags": ["c", 11], "pi": 0x1.921fb54442d18p+1,
//           "data": .Data("a2VsdmluCg=="), "when": .Date(0x1.0p+30), 0: nil ]  // any key
//         """)
//     if s.is(error) { println(s.error) }
//     var name = s["name"]                          // a copy, bound as any owner is
//     println(name.string)
//     s["new"] = SION.string($"added")               // a member added, or replaced
//     var text = SION.stringify(&s)                   // ["name":"kelvin",...]
//     var pretty = SION.stringify(&s, 2)              // one member a line, two spaces a level
//
// SION.parse takes a cstr or a String (borrowed, &s), and gives a SION:
// the value, or error("unexpected ']' at 12") with the message and the
// offset. SION.stringify takes a borrow of the value, &s, and a space,
// text or a number, that indents each level, none for compact text. A
// double is written as C's %a, a hex float that reads back exactly, an
// integer in decimal, a date as .Date(%a) of its seconds since 1970, data
// and an ext as .Data("base64") and .Ext("base64"). A dictionary keeps its
// entries in the order they were added, as an array of keys and values in
// turn, since a key may be any value; s["key"] and s[0] read and write by
// a string or an integer key, and SION.same(&a, &b) compares values.
#import <stdio.h> as C
#import <string.h> as C

enum SION { nil; boolean: bool; integer: i64; number: f64; string: String; data: Bytes; date: f64; ext: Bytes; array: Array<SION>; dictionary: Array<SION>; error: String }

// ---------- parsing ----------

struct SIONReader { at: cstr; i: i64; count: i64; depth: i64 }

// the parsing, as functions of the type (#111) in one block (#130), Self being SION (#140)
extend SION {
    static let readValue(var r:SIONReader^):Self

    // blanks, and comments from // to the end of the line
    static let skipSpace(var r:SIONReader^):() {
        while r^.i < r^.count {
            let c = r^.at[r^.i]
            if c == '/' && r^.i + 1 < r^.count && r^.at[r^.i + 1] == '/' {
                while r^.i < r^.count && r^.at[r^.i] != '\n' { r^.i += 1 }
                continue
            }
            if c != ' ' && c != '\t' && c != '\n' && c != '\r' { return }
            r^.i += 1
        }
    }

    static let fail(r:SIONReader^, what:cstr):Self {
        if r^.i >= r^.count { return Self.error($`${what}: unexpected end of text at ${r^.i}`) }
        let c = r^.at[r^.i]
        if c < 0x20 || c >= 0x7F { return Self.error($`${what}: unexpected byte ${c} at ${r^.i}`) }
        return Self.error($`${what}: unexpected '${c.uchr}' at ${r^.i}`)
    }

    static let word(var r:SIONReader^, word:cstr):bool {
        if r^.i + word.count as i64 > r^.count { return false }
        for k in 0..<word.count as i64 {
            if r^.at[r^.i + k] != word[k] { return false }
        }
        r^.i += word.count as i64
        return true
    }

    // the same, by letters of either case: nan, NaN, inf, Infinity
    static let wordNoCase(var r:SIONReader^, word:cstr):bool {
        if r^.i + word.count as i64 > r^.count { return false }
        for k in 0..<word.count as i64 {
            var c:u8 = r^.at[r^.i + k]
            if c >= 'A' && c <= 'Z' { c += 32 }
            if c != word[k] { return false }
        }
        r^.i += word.count as i64
        return true
    }

    static let hex(c:u8):i64 {
        if c >= '0' && c <= '9' { return (c - '0') as i64 }
        if c >= 'a' && c <= 'f' { return (c - 'a') as i64 + 10 }
        if c >= 'A' && c <= 'F' { return (c - 'A') as i64 + 10 }
        return -1
    }

    // four hex digits after \u, or -1
    static let unit(var r:SIONReader^):i64 {
        if r^.i + 4 > r^.count { return -1 }
        var v:i64 = 0
        for k in 0..<4 {
            let d = Self.hex(r^.at[r^.i + k])
            if d < 0 { return -1 }
            v = v * 16 + d
        }
        r^.i += 4
        return v
    }

    // one to eight hex digits in braces after \u, Swift's \u{1F600}, or -1
    static let braced(var r:SIONReader^):i64 {
        r^.i += 1   // {
        var v:i64 = 0
        var n = 0
        while r^.i < r^.count {
            let d = Self.hex(r^.at[r^.i])
            if d < 0 { break }
            n += 1
            if n > 8 { return -1 }
            v = v * 16 + d
            r^.i += 1
        }
        if n == 0 || r^.i >= r^.count || r^.at[r^.i] != '}' { return -1 }
        r^.i += 1
        return v
    }

    static let utf8(var b:Bytes^, cp:i64):() {
        if cp < 0x80 {
            b^ += cp as u8
        } else if cp < 0x800 {
            b^ += (0xC0 | (cp >> 6)) as u8
            b^ += (0x80 | (cp & 0x3F)) as u8
        } else if cp < 0x10000 {
            b^ += (0xE0 | (cp >> 12)) as u8
            b^ += (0x80 | ((cp >> 6) & 0x3F)) as u8
            b^ += (0x80 | (cp & 0x3F)) as u8
        } else {
            b^ += (0xF0 | (cp >> 18)) as u8
            b^ += (0x80 | ((cp >> 12) & 0x3F)) as u8
            b^ += (0x80 | ((cp >> 6) & 0x3F)) as u8
            b^ += (0x80 | (cp & 0x3F)) as u8
        }
    }

    // the text of a string, after its opening quote, into b; true when
    // closed: JSON's escapes, and Swift's \0 and \u{...}
    static let text(var r:SIONReader^, var b:Bytes^, var why:Self^):bool {
        while r^.i < r^.count {
            let c = r^.at[r^.i]
            if c == '"' {
                r^.i += 1
                return true
            }
            if c != '\\' {
                b^ += c
                r^.i += 1
                continue
            }
            r^.i += 1
            if r^.i >= r^.count { break }
            let e = r^.at[r^.i]
            r^.i += 1
            if e == '"' || e == '\\' || e == '/' {
                b^ += e
            } else if e == '0' {
                b^ += 0 as u8
            } else if e == 'b' {
                b^ += 8 as u8
            } else if e == 'f' {
                b^ += 12 as u8
            } else if e == 'n' {
                b^ += '\n'
            } else if e == 'r' {
                b^ += '\r'
            } else if e == 't' {
                b^ += '\t'
            } else if e == 'u' {
                var cp:i64 = -1
                if r^.i < r^.count && r^.at[r^.i] == '{' {
                    cp = Self.braced(r)
                    if cp < 0 {
                        why^ = Self.error($`one to eight hex digits in braces follow \\u at ${r^.i}`)
                        return false
                    }
                } else {
                    cp = Self.unit(r)
                    if cp < 0 {
                        why^ = Self.error($`four hex digits follow \\u at ${r^.i}`)
                        return false
                    }
                    if cp >= 0xD800 && cp <= 0xDBFF {   // a surrogate pair
                        if r^.i + 2 <= r^.count && r^.at[r^.i] == '\\' && r^.at[r^.i + 1] == 'u' {
                            r^.i += 2
                            let low = Self.unit(r)
                            if low < 0xDC00 || low > 0xDFFF {
                                why^ = Self.error($`a low surrogate follows a high one at ${r^.i}`)
                                return false
                            }
                            cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00)
                        } else {
                            why^ = Self.error($`a lone surrogate at ${r^.i}`)
                            return false
                        }
                    } else if cp >= 0xDC00 && cp <= 0xDFFF {
                        why^ = Self.error($`a lone surrogate at ${r^.i}`)
                        return false
                    }
                }
                if cp > 0x10FFFF {
                    why^ = Self.error($`no codepoint is past U+10FFFF at ${r^.i}`)
                    return false
                }
                Self.utf8(b, cp)
            } else {
                r^.i -= 1
                why^ = Self.fail(r, "an escape in a string")
                return false
            }
        }
        why^ = Self.error($`a string is not closed at ${r^.i}`)
        return false
    }

    static let readString(var r:SIONReader^):Self {
        r^.i += 1   // the opening quote
        var b = Bytes()
        var why = Self.nil
        if !Self.text(r, &b, &why) { return why }
        if !b.isUTF8 { return Self.error($`a string is not UTF-8 at ${r^.i}`) }
        return Self.string(String(&b))
    }

    static let digits(var r:SIONReader^, var b:Bytes^):bool {
        var seen = false
        while r^.i < r^.count && r^.at[r^.i] >= '0' && r^.at[r^.i] <= '9' {
            b^ += r^.at[r^.i]
            r^.i += 1
            seen = true
        }
        return seen
    }

    // digits of a base, 2, 8 or 16, as an integer
    static let based(var r:SIONReader^, base:i64, var v:i64^):bool {
        var seen = false
        while r^.i < r^.count {
            let d = Self.hex(r^.at[r^.i])
            if d < 0 || d >= base { break }
            v^ = v^ * base + d
            r^.i += 1
            seen = true
        }
        return seen
    }

    // an integer, 42, -42, 0x2a, 0o52, 0b101010; or a double, 42.0,
    // 4.2e1, 0x1.5p5, nan, inf, infinity, -inf, which has a point, an
    // exponent or a word
    static let readNumber(var r:SIONReader^):Self {
        var negative = false
        if r^.at[r^.i] == '-' || r^.at[r^.i] == '+' {
            negative = r^.at[r^.i] == '-'
            r^.i += 1
        }
        if r^.i >= r^.count { return Self.fail(r, "a number") }
        if Self.wordNoCase(r, "nan") { return Self.number(negative ? -(0.0 / 0.0) : 0.0 / 0.0) }
        if Self.wordNoCase(r, "infinity") || Self.wordNoCase(r, "inf") {
            return Self.number(negative ? -(1.0 / 0.0) : 1.0 / 0.0)
        }
        if r^.at[r^.i] == '0' && r^.i + 1 < r^.count {
            let k = r^.at[r^.i + 1]
            if k == 'x' || k == 'X' {
                // hex: an integer, or a float with a point or a p exponent
                let start = r^.i
                r^.i += 2
                var v:i64 = 0
                if !Self.based(r, 16, &v) { return Self.fail(r, "hex digits after 0x") }
                var isFloat = false
                if r^.i < r^.count && r^.at[r^.i] == '.' {
                    isFloat = true
                    r^.i += 1
                    var frac:i64 = 0
                    Self.based(r, 16, &frac)
                }
                if r^.i < r^.count && (r^.at[r^.i] == 'p' || r^.at[r^.i] == 'P') {
                    isFloat = true
                    r^.i += 1
                    if r^.i < r^.count && (r^.at[r^.i] == '+' || r^.at[r^.i] == '-') { r^.i += 1 }
                    var b = Bytes()
                    if !Self.digits(r, &b) { return Self.fail(r, "a digit in the exponent") }
                }
                if isFloat {
                    var b = Bytes()
                    for k in start..<r^.i { b += r^.at[k] }
                    let x = f64(b.cstr)
                    return Self.number(negative ? -x : x)
                }
                return Self.integer(negative ? -v : v)
            }
            if k == 'o' || k == 'O' || k == 'b' || k == 'B' {
                r^.i += 2
                var v:i64 = 0
                if !Self.based(r, k == 'o' || k == 'O' ? 8 : 2, &v) { return Self.fail(r, "digits after the base") }
                return Self.integer(negative ? -v : v)
            }
        }
        var b = Bytes()
        if !Self.digits(r, &b) { return Self.fail(r, "a number") }
        var isFloat = false
        if r^.i < r^.count && r^.at[r^.i] == '.' {
            isFloat = true
            b += '.'
            r^.i += 1
            if !Self.digits(r, &b) { return Self.fail(r, "a digit after the point") }
        }
        if r^.i < r^.count && (r^.at[r^.i] == 'e' || r^.at[r^.i] == 'E') {
            isFloat = true
            b += 'e'
            r^.i += 1
            if r^.i < r^.count && (r^.at[r^.i] == '+' || r^.at[r^.i] == '-') {
                b += r^.at[r^.i]
                r^.i += 1
            }
            if !Self.digits(r, &b) { return Self.fail(r, "a digit in the exponent") }
        }
        if isFloat {
            let x = f64(b.cstr)
            return Self.number(negative ? -x : x)
        }
        var v:i64 = 0
        for c in b { v = v * 10 + (c - '0') as i64 }
        return Self.integer(negative ? -v : v)
    }

    // the value of a base64 letter, or -1
    static let sextet(c:u8):i64 {
        if c >= 'A' && c <= 'Z' { return (c - 'A') as i64 }
        if c >= 'a' && c <= 'z' { return (c - 'a') as i64 + 26 }
        if c >= '0' && c <= '9' { return (c - '0') as i64 + 52 }
        if c == '+' { return 62 }
        if c == '/' { return 63 }
        return -1
    }

    // the bytes of base64 text, letters other than its own skipped, as
    // Foundation reads it; none for text that is not base64
    static let unbase64(text:const Bytes^, var out:Bytes^):bool {
        var acc:i64 = 0
        var bits:i64 = 0
        for c in text^ {
            if c == '=' { break }
            let v = Self.sextet(c)
            if v < 0 { continue }
            acc = (acc << 6) | v
            bits += 6
            if bits >= 8 {
                bits -= 8
                out^ += ((acc >> bits) & 0xFF) as u8
            }
        }
        return true
    }

    // .Data("base64"), .Ext("base64") and .Date(double), at the dot
    static let readDotted(var r:SIONReader^):Self {
        if Self.word(r, ".Date(") {
            Self.skipSpace(r)
            var d = Self.readNumber(r)
            if d.is(error) { return Self.error(d.error.copy()) }
            Self.skipSpace(r)
            if r^.i >= r^.count || r^.at[r^.i] != ')' { return Self.fail(r, "')' after .Date(") }
            r^.i += 1
            if d.is(integer) { return Self.date(f64(d.integer)) }
            return Self.date(d.number)
        }
        let isData = Self.word(r, ".Data(")
        if !isData && !Self.word(r, ".Ext(") { return Self.fail(r, "a value") }
        Self.skipSpace(r)
        if r^.i >= r^.count || r^.at[r^.i] != '"' { return Self.fail(r, "a base64 string after .Data( or .Ext(") }
        r^.i += 1
        var text = Bytes()
        while r^.i < r^.count && r^.at[r^.i] != '"' {
            text += r^.at[r^.i]
            r^.i += 1
        }
        if r^.i >= r^.count { return Self.fail(r, "the closing quote of a base64 string") }
        r^.i += 1
        Self.skipSpace(r)
        if r^.i >= r^.count || r^.at[r^.i] != ')' { return Self.fail(r, "')' after a base64 string") }
        r^.i += 1
        var bytes = Bytes()
        Self.unbase64(&text, &bytes)
        if isData {
            var d = Self.data(bytes)
            bytes = Bytes()   // moved out above: anew, so that the ext below may take it
            return d
        }
        return Self.ext(bytes)
    }

    // [ ... ]: an array, or a dictionary where a ':' follows the first
    // value, [:] an empty one; the dictionary's keys and values in turn
    static let readCollection(var r:SIONReader^):Self {
        r^.i += 1   // [
        var items:Array<Self> = Array<Self>()
        Self.skipSpace(r)
        if r^.i < r^.count && r^.at[r^.i] == ']' {
            r^.i += 1
            return Self.array(Array<Self>())
        }
        if r^.i < r^.count && r^.at[r^.i] == ':' {
            r^.i += 1
            Self.skipSpace(r)
            if r^.i >= r^.count || r^.at[r^.i] != ']' { return Self.fail(r, "']' after '[:'") }
            r^.i += 1
            return Self.dictionary(Array<Self>())
        }
        var isDictionary = false
        var first = true
        while true {
            items += Self.readValue(r)
            if items[items.count - 1].is(error) { return Self.error(items[items.count - 1].error.copy()) }
            Self.skipSpace(r)
            if first {
                first = false
                if r^.i < r^.count && r^.at[r^.i] == ':' { isDictionary = true }
            }
            if isDictionary {
                if r^.i >= r^.count || r^.at[r^.i] != ':' { return Self.fail(r, "':' after a key") }
                r^.i += 1
                items += Self.readValue(r)
                if items[items.count - 1].is(error) { return Self.error(items[items.count - 1].error.copy()) }
                Self.skipSpace(r)
            }
            if r^.i >= r^.count { return Self.fail(r, isDictionary ? "a dictionary" : "an array") }
            let c = r^.at[r^.i]
            r^.i += 1
            if c == ']' { break }
            if c != ',' {
                r^.i -= 1
                return Self.fail(r, isDictionary ? "',' or ']' in a dictionary" : "',' or ']' in an array")
            }
            Self.skipSpace(r)
            if r^.i < r^.count && r^.at[r^.i] == ']' {   // a trailing comma
                r^.i += 1
                break
            }
        }
        if isDictionary {
            var d = Self.dictionary(items)
            items = Array<Self>()   // moved out above: anew, so that the array below may take it
            return d
        }
        return Self.array(items)
    }

    static let readValue(var r:SIONReader^):Self {
        Self.skipSpace(r)
        if r^.i >= r^.count { return Self.fail(r, "a value") }
        let c = r^.at[r^.i]
        if c == '[' {
            if r^.depth >= 512 { return Self.error($`nesting deeper than 512 at ${r^.i}`) }
            r^.depth += 1
            var v = Self.readCollection(r)
            r^.depth -= 1
            return v
        }
        if c == '"' { return Self.readString(r) }
        if c == '-' || c == '+' || (c >= '0' && c <= '9') { return Self.readNumber(r) }
        if c == '.' { return Self.readDotted(r) }
        if c == 't' && Self.word(r, "true") { return Self.boolean(true) }
        if c == 'f' && Self.word(r, "false") { return Self.boolean(false) }
        if c == 'n' {
            if Self.word(r, "nil") { return Self.nil }
            if Self.wordNoCase(r, "nan") { return Self.number(0.0 / 0.0) }
        }
        if c == 'N' && Self.wordNoCase(r, "nan") { return Self.number(0.0 / 0.0) }
        if (c == 'i' || c == 'I') && (Self.wordNoCase(r, "infinity") || Self.wordNoCase(r, "inf")) {
            return Self.number(1.0 / 0.0)
        }
        return Self.fail(r, "a value")
    }

    static let parse(text:cstr):Self {
        var r:SIONReader = {text, 0, text.count as i64, 0}
        var v = Self.readValue(&r)
        if !v.is(error) {
            Self.skipSpace(&r)
            if r.i < r.count { return Self.fail(&r, "the end of the text") }
        }
        return v
    }

    static let parse(text:const String^):Self { Self.parse(text^.cstr) }
}

// ---------- writing ----------

extend SION {
    // a double as C's %a, the hex float that reads back exactly, without
    // the sign .hex adds; nan, inf and -inf as they are
    static let showNumber(x:f64):String {
        if x != x { return $"nan" }
        if x > 1.7976931348623157e308 { return $"inf" }
        if x < -1.7976931348623157e308 { return $"-inf" }
        let t := x.hex
        return String(t[0] == '+' ? &t[1] : t)
    }

    // a string quoted as Swift's debugDescription quotes it: \", \\, \n,
    // \r, \t, \0, and \u{XX} for the other control characters
    static let quote(s:const String^, var out:String^):() {
        let hex := "0123456789abcdef"
        out^ += "\""
        for c in s^ {
            let n = c.codepoint
            if n == 0x22 {
                out^ += "\\\""
            } else if n == 0x5C {
                out^ += "\\\\"
            } else if n == 0x0A {
                out^ += "\\n"
            } else if n == 0x0D {
                out^ += "\\r"
            } else if n == 0x09 {
                out^ += "\\t"
            } else if n == 0 {
                out^ += "\\0"
            } else if n < 0x20 || n == 0x7F {
                out^ += "\\u{"
                if n >= 0x10 { out^ += hex[(n >> 4) as i64] }
                out^ += hex[(n & 15) as i64]
                out^ += "}"
            } else {
                out^ += c
            }
        }
        out^ += "\""
    }

    static let base64(b:const Bytes^, var out:String^):() {
        let letters := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        var i:i64 = 0
        let n = b^.count as i64
        while i + 2 < n {
            let v:i64 = ((b^[i] as i64) << 16) | ((b^[i + 1] as i64) << 8) | (b^[i + 2] as i64)
            out^ += letters[v >> 18]
            out^ += letters[(v >> 12) & 63]
            out^ += letters[(v >> 6) & 63]
            out^ += letters[v & 63]
            i += 3
        }
        if i + 1 == n {
            let v:i64 = (b^[i] as i64) << 16
            out^ += letters[v >> 18]
            out^ += letters[(v >> 12) & 63]
            out^ += "=="
        } else if i + 2 == n {
            let v:i64 = ((b^[i] as i64) << 16) | ((b^[i + 1] as i64) << 8)
            out^ += letters[v >> 18]
            out^ += letters[(v >> 12) & 63]
            out^ += letters[(v >> 6) & 63]
            out^ += "="
        }
    }

    static let indent(var out:String^, space:cstr, level:i64):() {
        if space.count == 0 { return }
        out^ += "\n"
        for k in 0..<level { out^ += space }
    }

    static let write(v:const Self^, space:cstr, level:i64, var out:String^):() {
        switch v^ {
        case nil: out^ += "nil"
        case boolean: out^ += v^.boolean ? "true" : "false"
        case integer: out^ += v^.integer.cstr
        case number:
            var n = Self.showNumber(v^.number)
            out^ += &n
        case string: Self.quote(&v^.string, out)
        case error: Self.quote(&v^.error, out)
        case date:
            var n = Self.showNumber(v^.date)
            out^ += ".Date("
            out^ += &n
            out^ += ")"
        case data:
            out^ += ".Data(\""
            Self.base64(&v^.data, out)
            out^ += "\")"
        case ext:
            out^ += ".Ext(\""
            Self.base64(&v^.ext, out)
            out^ += "\")"
        case array:
            if v^.array.count == 0 {
                out^ += "[]"
                return
            }
            out^ += "["
            var i:i64 = 0
            for x in v^.array {
                if i > 0 { out^ += "," }
                Self.indent(out, space, level + 1)
                Self.write(&x, space, level + 1, out)
                i += 1
            }
            Self.indent(out, space, level)
            out^ += "]"
        case dictionary:
            if v^.dictionary.count == 0 {
                out^ += "[:]"
                return
            }
            out^ += "["
            var i:i64 = 0
            for x in v^.dictionary {
                if i % 2 == 0 {
                    if i > 0 { out^ += "," }
                    Self.indent(out, space, level + 1)
                    Self.write(&x, space, level + 1, out)
                    out^ += space.count > 0 ? " : " : ":"
                } else {
                    Self.write(&x, space, level + 1, out)
                }
                i += 1
            }
            Self.indent(out, space, level)
            out^ += "]"
        }
    }

    static let spaces(n:i64):cstr {
        let spaces:cstr := "          "
        return &spaces[n < 0 ? 10 : n > 10 ? 0 : 10 - n]
    }

    static let stringify(v:const Self^, space:cstr):String {
        var out = $""
        var unit = Bytes()
        for k in 0..<space.count as i64 {
            if k >= 10 { break }
            unit += space[k]
        }
        Self.write(v, unit.cstr, 0, &out)
        return out
    }
    static let stringify(v:const Self^):String { Self.stringify(v, "") }
    static let stringify(v:const Self^, space:const String^):String { Self.stringify(v, space^.cstr) }
    static let stringify(v:const Self^, space:i64):String { Self.stringify(v, Self.spaces(space)) }
}

// ---------- values ----------

extend SION {
    // are a and b the same value, member by member?
    static let same(a:const Self^, b:const Self^):bool {
        if a^.case != b^.case { return false }
        switch a^ {
        case nil: return true
        case boolean: return a^.boolean == b^.boolean
        case integer: return a^.integer == b^.integer
        case number: return a^.number == b^.number
        case date: return a^.date == b^.date
        case string: return a^.string == b^.string
        case error: return a^.error == b^.error
        case data: return a^.data == b^.data
        case ext: return a^.ext == b^.ext
        case array:
            if a^.array.count != b^.array.count { return false }
            for i in 0..<a^.array.count as i64 {
                if !Self.same(&a^.array[i], &b^.array[i]) { return false }
            }
            return true
        case dictionary:
            if a^.dictionary.count != b^.dictionary.count { return false }
            for i in 0..<a^.dictionary.count as i64 {
                if !Self.same(&a^.dictionary[i], &b^.dictionary[i]) { return false }
            }
            return true
        }
    }

    // the index of key's value in a dictionary, or -1
    static let find(d:const Self^, key:const Self^):i64 {
        if !d^.is(dictionary) { return -1 }
        var i:i64 = 0
        while i + 1 < d^.dictionary.count as i64 {
            if Self.same(&d^.dictionary[i], key) { return i + 1 }
            i += 2
        }
        return -1
    }

    // the count of an array's elements or a dictionary's entries, or 0
    let count:i64 {
        if .is(array) { return .array.count as i64 }
        if .is(dictionary) { return .dictionary.count as i64 / 2 }
        return 0
    }

    // s["key"] and s[0]: a copy of the value under a string or an integer
    // key of a dictionary, or of an array's element by an index; nil
    // where there is none. Setting replaces, or adds at the end, and
    // s[i] = v sets an array's element
    var [](key:cstr):Self {
        get {
            var k = Self.string(String(key))
            let at = Self.find(&self, &k)
            return at < 0 ? Self.nil : .dictionary[at].copy()
        }
        set(v) {
            var k = Self.string(String(key))
            let at = Self.find(&self, &k)
            if at >= 0 {
                .dictionary[at] = v.copy()
            } else if .is(dictionary) {
                .dictionary += Self.string(String(key))
                .dictionary += v.copy()
            }
        }
    }
    var [](i:i64):Self {
        get {
            if .is(array) { return i >= 0 && i < .array.count as i64 ? .array[i].copy() : Self.nil }
            var k = Self.integer(i)
            let at = Self.find(&self, &k)
            return at < 0 ? Self.nil : .dictionary[at].copy()
        }
        set(v) {
            if .is(array) {
                if i >= 0 && i < .array.count as i64 { .array[i] = v.copy() }
                return
            }
            var k = Self.integer(i)
            let at = Self.find(&self, &k)
            if at >= 0 {
                .dictionary[at] = v.copy()
            } else if .is(dictionary) {
                .dictionary += Self.integer(i)
                .dictionary += v.copy()
            }
        }
    }
}
