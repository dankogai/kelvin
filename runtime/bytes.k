// runtime/bytes.k - a Bytes's Base64 (#155), written in Kelvin (#290):
// kelvinc --runtime builds it into libkelvin, each kv_ function by the
// name kelvin_prelude.h declares. The helpers are static, C's.
#import <string.h> as C

// b.toBase64(url, nopad): the bytes as Base64 text, the URL alphabet's
// - and _ for + and /, padded with = to a multiple of four unless not
let kv_bytes_base64(b:const Bytes^, url:bool, pad:bool):String {
    let letters:cstr := url ? "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_" : "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    let n = b^.count as int64
    var out = $""
    out.reserve(((n + 2) / 3 * 4) as size_t)
    var i:int64 = 0
    while i + 2 < n {
        let v:u32 = ((b^[i] as u32) << 16) | ((b^[i + 1] as u32) << 8) | (b^[i + 2] as u32)
        out += (letters[v >> 18] as u32).uchr
        out += (letters[(v >> 12) & 63] as u32).uchr
        out += (letters[(v >> 6) & 63] as u32).uchr
        out += (letters[v & 63] as u32).uchr
        i += 3
    }
    if i + 1 == n {
        let v:u32 = (b^[i] as u32) << 16
        out += (letters[v >> 18] as u32).uchr
        out += (letters[(v >> 12) & 63] as u32).uchr
        if pad { out += "==" }
    } else if i + 2 == n {
        let v:u32 = ((b^[i] as u32) << 16) | ((b^[i + 1] as u32) << 8)
        out += (letters[v >> 18] as u32).uchr
        out += (letters[(v >> 12) & 63] as u32).uchr
        out += (letters[(v >> 6) & 63] as u32).uchr
        if pad { out += "=" }
    }
    return out
}

// a letter of either alphabet as its value, -1 for a blank, -2 otherwise
static let base64_value(c:u8):int32 {
    if c >= 'A' && c <= 'Z' { return (c - 'A') as int32 }
    if c >= 'a' && c <= 'z' { return (c - 'a' + 26) as int32 }
    if c >= '0' && c <= '9' { return (c - '0' + 52) as int32 }
    if c == '+' || c == '-' { return 62 }
    if c == '/' || c == '_' { return 63 }
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' { return -1 }
    return -2
}

// Bytes.fromBase64(text) of the n bytes at p: either alphabet, blanks
// skipped, the padding and what follows it ignored; text that is not
// Base64 ends the program, as an index out of range does
let kv_bytes_from_base64(p:const any^, n:size_t):Bytes {
    let s:cstr := p as cstr
    var out = Bytes()
    out.reserve(n / 4 * 3 + 2)
    var acc:u32 = 0
    var bits:int32 = 0
    for i in 0..<n {
        if s[i] == '=' { break }                 // the padding, and nothing after it
        let v = base64_value(s[i])
        if v == -1 { continue }
        if v < 0 { kv_array_fail("Bytes.fromBase64 of text that is not base64") }
        acc = (acc << 6) | (v as u32)
        bits += 6
        if bits >= 8 {
            bits -= 8
            out += ((acc >> (bits as u32)) & 0xFF) as u8
        }
    }
    return out
}

let kv_bytes_from_base64_text(s:const any^):Bytes {
    if s == nullptr { return Bytes() }
    return kv_bytes_from_base64(s, strlen(s))
}

// Bytes(&s) of a String (#291): a copy of its bytes, which KV_BYTES_OF
// took for text before, reading the String's own fields
let kv_bytes_of_string(s:const String^):Bytes { s^.bytes^.copy() }
