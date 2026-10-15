// modules/JSON.k - JSON values, parsed from text and written back (#113):
// JSON is an enum with values, a tagged union of a null, a bool, an f64,
// a String, an Array<JSON> or a Dictionary<String, JSON>, with one more
// case, error, for a text that is not JSON.
//
//     #import <JSON>
//     var j = JSON.parse(`{"name": "kelvin", "tags": ["c", 11], "ok": true}`)
//     if j.is(error) { println(j.error) }
//     println(j.object["name"].string, " ", j.object["tags"].array[1].number)
//     j.object["tags"].array += JSON.number(12.0)
//     var text = JSON.stringify(&j, "  ")           // pretty, two spaces a level
//     var flat = JSON.stringify(&j)                 // compact
//
// JSON.parse takes a cstr or a String (borrowed, &s), and gives a JSON
// straight: the value, or error("unexpected ']' at 12") with the message
// and the offset. JSON.stringify takes a borrow of the value, &j, and, as
// JS's does, a replacer and a space: the replacer is a function
// (key:cstr, value:const JSON^):JSON? called for the root with key "",
// for each member with its key and for each element with its index as
// text, and what it gives is written, none leaving a member out and
// writing null for an element; the space is text, a cstr or a String,
// that indents each level, at most 10 characters, "" for compact text,
// or a number, that many spaces a level, 0 to 10, as JS's takes one.
// Numbers are written as JS writes them, the shortest text that reads
// back, 3 for 3.0; NaN and the infinities are null. Members are written
// in the order they were added, as a Dictionary keeps them.
#import <stdio.h> as C

enum JSON { null; boolean: bool; number: f64; string: String; array: Array<JSON>; object: Dictionary<String, JSON>; error: String }

// ---------- parsing ----------

struct JSONReader { at: cstr; i: i64; count: i64; depth: i64 }

static let JSON_value(var r:JSONReader^):JSON

static let JSON_space(var r:JSONReader^):() {
    while r^.i < r^.count {
        let c = r^.at[r^.i]
        if c != ' ' && c != '\t' && c != '\n' && c != '\r' { return }
        r^.i += 1
    }
}

static let JSON_fail(r:JSONReader^, what:cstr):JSON {
    if r^.i >= r^.count { return JSON.error($`${what}: unexpected end of text at ${r^.i}`) }
    let c = r^.at[r^.i]
    if c < 0x20 || c >= 0x7F { return JSON.error($`${what}: unexpected byte ${c} at ${r^.i}`) }
    return JSON.error($`${what}: unexpected '${c.uchr}' at ${r^.i}`)
}

static let JSON_word(var r:JSONReader^, word:cstr):bool {
    if r^.i + word.count as i64 > r^.count { return false }
    for k in 0..<word.count as i64 {
        if r^.at[r^.i + k] != word[k] { return false }
    }
    r^.i += word.count as i64
    return true
}

static let JSON_hex(c:u8):i64 {
    if c >= '0' && c <= '9' { return (c - '0') as i64 }
    if c >= 'a' && c <= 'f' { return (c - 'a') as i64 + 10 }
    if c >= 'A' && c <= 'F' { return (c - 'A') as i64 + 10 }
    return -1
}

// four hex digits after \u, or -1
static let JSON_unit(var r:JSONReader^):i64 {
    if r^.i + 4 > r^.count { return -1 }
    var v:i64 = 0
    for k in 0..<4 {
        let d = JSON_hex(r^.at[r^.i + k])
        if d < 0 { return -1 }
        v = v * 16 + d
    }
    r^.i += 4
    return v
}

static let JSON_utf8(var b:Bytes^, cp:i64):() {
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

// the text of a string, after its opening quote, into b; true when closed
static let JSON_text(var r:JSONReader^, var b:Bytes^, var why:JSON^):bool {
    while r^.i < r^.count {
        let c = r^.at[r^.i]
        if c == '"' {
            r^.i += 1
            return true
        }
        if c < 0x20 {
            why^ = JSON_fail(r, "a control character in a string")
            return false
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
            var cp = JSON_unit(r)
            if cp < 0 {
                why^ = JSON.error($`four hex digits follow \\u at ${r^.i}`)
                return false
            }
            if cp >= 0xD800 && cp <= 0xDBFF {   // a surrogate pair
                if r^.i + 2 <= r^.count && r^.at[r^.i] == '\\' && r^.at[r^.i + 1] == 'u' {
                    r^.i += 2
                    let low = JSON_unit(r)
                    if low < 0xDC00 || low > 0xDFFF {
                        why^ = JSON.error($`a low surrogate follows a high one at ${r^.i}`)
                        return false
                    }
                    cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00)
                } else {
                    why^ = JSON.error($`a lone surrogate at ${r^.i}`)
                    return false
                }
            } else if cp >= 0xDC00 && cp <= 0xDFFF {
                why^ = JSON.error($`a lone surrogate at ${r^.i}`)
                return false
            }
            JSON_utf8(b, cp)
        } else {
            r^.i -= 1
            why^ = JSON_fail(r, "an escape in a string")
            return false
        }
    }
    why^ = JSON.error($`a string is not closed at ${r^.i}`)
    return false
}

static let JSON_string(var r:JSONReader^):JSON {
    r^.i += 1   // the opening quote
    var b = Bytes()
    var why = JSON.null
    if !JSON_text(r, &b, &why) { return why }
    if !b.isUTF8 { return JSON.error($`a string is not UTF-8 at ${r^.i}`) }
    return JSON.string(b.string())
}

static let JSON_digits(var r:JSONReader^, var b:Bytes^):bool {
    var seen = false
    while r^.i < r^.count && r^.at[r^.i] >= '0' && r^.at[r^.i] <= '9' {
        b^ += r^.at[r^.i]
        r^.i += 1
        seen = true
    }
    return seen
}

static let JSON_number(var r:JSONReader^):JSON {
    var b = Bytes()
    if r^.at[r^.i] == '-' {
        b += '-'
        r^.i += 1
    }
    if r^.i < r^.count && r^.at[r^.i] == '0' {
        b += '0'
        r^.i += 1
    } else if !JSON_digits(r, &b) {
        return JSON_fail(r, "a number")
    }
    if r^.i < r^.count && r^.at[r^.i] == '.' {
        b += '.'
        r^.i += 1
        if !JSON_digits(r, &b) { return JSON_fail(r, "a digit after the point") }
    }
    if r^.i < r^.count && (r^.at[r^.i] == 'e' || r^.at[r^.i] == 'E') {
        b += 'e'
        r^.i += 1
        if r^.i < r^.count && (r^.at[r^.i] == '+' || r^.at[r^.i] == '-') {
            b += r^.at[r^.i]
            r^.i += 1
        }
        if !JSON_digits(r, &b) { return JSON_fail(r, "a digit in the exponent") }
    }
    return JSON.number(f64(b))
}

static let JSON_array(var r:JSONReader^):JSON {
    r^.i += 1   // [
    var a:Array<JSON> = Array<JSON>()
    JSON_space(r)
    var open = !(r^.i < r^.count && r^.at[r^.i] == ']')
    if !open { r^.i += 1 }
    while open {
        a += JSON_value(r)
        if a[a.count - 1].is(error) { return JSON.error(a[a.count - 1].error.copy()) }
        JSON_space(r)
        if r^.i >= r^.count { return JSON_fail(r, "an array") }
        let c = r^.at[r^.i]
        r^.i += 1
        if c == ']' { break }
        if c != ',' {
            r^.i -= 1
            return JSON_fail(r, "',' or ']' in an array")
        }
    }
    return JSON.array(a)
}

static let JSON_object(var r:JSONReader^):JSON {
    r^.i += 1   // {
    var o:Dictionary<String, JSON> = Dictionary<String, JSON>()
    JSON_space(r)
    var open = !(r^.i < r^.count && r^.at[r^.i] == '}')
    if !open { r^.i += 1 }
    while open {
        JSON_space(r)
        if r^.i >= r^.count || r^.at[r^.i] != '"' { return JSON_fail(r, "a key in an object") }
        var key = JSON_string(r)
        if key.is(error) { return JSON.error(key.error.copy()) }
        JSON_space(r)
        if r^.i >= r^.count || r^.at[r^.i] != ':' { return JSON_fail(r, "':' after a key") }
        r^.i += 1
        o[key.string] = JSON_value(r)
        if o[key.string].is(error) { return JSON.error(o[key.string].error.copy()) }
        JSON_space(r)
        if r^.i >= r^.count { return JSON_fail(r, "an object") }
        let c = r^.at[r^.i]
        r^.i += 1
        if c == '}' { break }
        if c != ',' {
            r^.i -= 1
            return JSON_fail(r, "',' or '}' in an object")
        }
    }
    return JSON.object(o)
}

static let JSON_value(var r:JSONReader^):JSON {
    JSON_space(r)
    if r^.i >= r^.count { return JSON_fail(r, "a value") }
    let c = r^.at[r^.i]
    if c == '{' || c == '[' {
        if r^.depth >= 512 { return JSON.error($`nesting deeper than 512 at ${r^.i}`) }
        r^.depth += 1
        var v = c == '{' ? JSON_object(r) : JSON_array(r)
        r^.depth -= 1
        return v
    }
    if c == '"' { return JSON_string(r) }
    if c == '-' || (c >= '0' && c <= '9') { return JSON_number(r) }
    if c == 't' && JSON_word(r, "true") { return JSON.boolean(true) }
    if c == 'f' && JSON_word(r, "false") { return JSON.boolean(false) }
    if c == 'n' && JSON_word(r, "null") { return JSON.null }
    return JSON_fail(r, "a value")
}

extend JSON {
    static let parse(text:cstr):Self {                      // Self is JSON (#140)
        var r:JSONReader = {text, 0, text.count as i64, 0}
        var v = JSON_value(&r)
        if !v.is(error) {
            JSON_space(&r)
            if r.i < r.count { return JSON_fail(&r, "the end of the text") }
        }
        return v
    }

    static let parse(text:const String^):Self { Self.parse(text^.cstr) }
}

// ---------- writing ----------

// a number as JS writes it: the shortest text that reads back, no point
// for a whole number, exponents past 1e21 and below 1e-6; NaN and the
// infinities are null
static let JSON_show_number(x:f64):String {
    if x != x || x > 1.7976931348623157e308 || x < -1.7976931348623157e308 { return $"null" }
    if x == 0.0 { return $"0" }
    var b = Bytes(40)
    var p:i32 = 15
    while p <= 17 {
        snprintf(b.at, 40, "%.*g", p, x)
        if f64(b.at) == x { break }
        p += 1
    }
    let text:cstr := b.at
    var e:i64 = -1
    for k in 0..<text.count as i64 {
        if text[k] == 'e' { e = k }
    }
    if e < 0 { return String(text) }
    // mantissa and exponent, as %g gave them
    var digits = Bytes()
    var negative = false
    for k in 0..<e {
        if text[k] == '-' { negative = true }
        else if text[k] != '.' { digits += text[k] }
    }
    var exponent:i64 = 0
    var negativeExponent = false
    for k in (e + 1)..<text.count as i64 {
        let c = text[k]
        if c == '-' { negativeExponent = true }
        else if c >= '0' && c <= '9' { exponent = exponent * 10 + (c - '0') as i64 }
    }
    if negativeExponent { exponent = -exponent }
    var out = $""
    if negative { out += "-" }
    if exponent >= 21 || exponent <= -7 {
        out += digits[0]
        if digits.count > 1 {
            out += "."
            for k in 1..<digits.count as i64 { out += digits[k] }
        }
        out += exponent < 0 ? "e-" : "e+"
        var m:i64 = exponent < 0 ? -exponent : exponent
        out += m.cstr
    } else if exponent < 0 {
        out += "0."
        for k in 0..<(-exponent - 1) { out += "0" }
        for k in 0..<digits.count as i64 { out += digits[k] }
    } else {
        for k in 0...exponent {
            out += k < digits.count as i64 ? digits[k] : '0'
        }
        if digits.count as i64 > exponent + 1 {
            out += "."
            for k in (exponent + 1)..<digits.count as i64 { out += digits[k] }
        }
    }
    return out
}

static let JSON_quote(s:const String^, var out:String^):() {
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
        } else if n == 0x08 {
            out^ += "\\b"
        } else if n == 0x0C {
            out^ += "\\f"
        } else if n < 0x20 {
            out^ += "\\u00"
            out^ += hex[(n >> 4) as i64]
            out^ += hex[(n & 15) as i64]
        } else {
            out^ += c
        }
    }
    out^ += "\""
}

static let JSON_indent(var out:String^, space:cstr, level:i64):() {
    if space.count == 0 { return }
    out^ += "\n"
    for k in 0..<level { out^ += space }
}

static let JSON_write(j:const JSON^, replacer:(cstr, const JSON^):JSON?, space:cstr, level:i64, var out:String^)

// the value a member or an element is written as: the replacer's, or itself
static let JSON_write_item(key:cstr, v:const JSON^, replacer:(cstr, const JSON^):JSON?, space:cstr, level:i64, var out:String^):bool {
    if replacer.isNull {
        JSON_write(v, replacer, space, level, out)
        return true
    }
    var r = replacer(key, v)
    if let some(x) = r {
        JSON_write(&x, replacer, space, level, out)
        return true
    }
    return false
}

static let JSON_write(j:const JSON^, replacer:(cstr, const JSON^):JSON?, space:cstr, level:i64, var out:String^) {
    switch j^ {
    case null: out^ += "null"
    case boolean: out^ += j^.boolean ? "true" : "false"
    case number:
        var n = JSON_show_number(j^.number)
        out^ += &n
    case string: JSON_quote(&j^.string, out)
    case error: JSON_quote(&j^.error, out)
    case array:
        if j^.array.count == 0 {
            out^ += "[]"
            return
        }
        out^ += "["
        var i:i64 = 0
        for x in j^.array {
            if i > 0 { out^ += "," }
            JSON_indent(out, space, level + 1)
            let index := i.cstr
            if !JSON_write_item(index, &x, replacer, space, level + 1, out) { out^ += "null" }
            i += 1
        }
        JSON_indent(out, space, level)
        out^ += "]"
    case object:
        if j^.object.count == 0 {
            out^ += "{}"
            return
        }
        out^ += "{"
        var first = true
        for k, v in j^.object {
            var member = $""
            if !JSON_write_item(k.cstr, &v, replacer, space, level + 1, &member) { continue }
            if !first { out^ += "," }
            first = false
            JSON_indent(out, space, level + 1)
            JSON_quote(&k, out)
            out^ += space.count > 0 ? ": " : ":"
            out^ += &member
        }
        if first {
            out^ += "}"
            return
        }
        JSON_indent(out, space, level)
        out^ += "}"
    }
}

static let JSON_stringify(j:const JSON^, replacer:(cstr, const JSON^):JSON?, space:cstr):String {
    var out = $""
    var unit = Bytes()
    for k in 0..<space.count as i64 {
        if k >= 10 { break }   // as JS's, at most 10 characters
        unit += space[k]
    }
    if !JSON_write_item("", j, replacer, unit.cstr, 0, &out) { return $"" }
    return out
}

// a number as the space (#129): that many spaces a level, 0 to 10, as JS's
// JSON.stringify takes one and as v.pretty(n) indents
static let JSON_spaces(n:i64):cstr {
    let spaces:cstr := "          "
    return &spaces[n < 0 ? 10 : n > 10 ? 0 : 10 - n]
}

// the space as text, a String, a number, or none for compact text; a
// replacer before it, or none (#130: the functions of JSON, in one block)
extend JSON {
    static let stringify(j:const Self^):String { JSON_stringify(j, nullptr, "") }
    static let stringify(j:const Self^, space:cstr):String { JSON_stringify(j, nullptr, space) }
    static let stringify(j:const Self^, space:const String^):String { JSON_stringify(j, nullptr, space^.cstr) }
    static let stringify(j:const Self^, space:i64):String { JSON_stringify(j, nullptr, JSON_spaces(space)) }
    static let stringify(j:const Self^, replacer:(cstr, const Self^):Self?):String { JSON_stringify(j, replacer, "") }
    static let stringify(j:const Self^, replacer:(cstr, const Self^):Self?, space:cstr):String { JSON_stringify(j, replacer, space) }
    static let stringify(j:const Self^, replacer:(cstr, const Self^):Self?, space:const String^):String {
        JSON_stringify(j, replacer, space^.cstr)
    }
    static let stringify(j:const Self^, replacer:(cstr, const Self^):Self?, space:i64):String {
        JSON_stringify(j, replacer, JSON_spaces(space))
    }
}
