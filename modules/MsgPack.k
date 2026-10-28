// modules/MsgPack.k - MessagePack (#153), https://msgpack.org, packed from
// and unpacked into SION values, whose model it shares: nil, bool, an
// integer, a double, a string, data, a date, an ext, an array and a map
// keyed by any value.
//
//     #import <MsgPack>
//     var s = SION.parse("[\"name\": \"kelvin\", \"n\": 42, \"when\": .Date(0x1p+30)]")
//     var packed = MsgPack.pack(&s)              // a Bytes: 83 a4 name ...
//     var back = MsgPack.unpack(&packed)         // the SION again, or error("...")
//     println(SION.same(&s, &back))               // true
//
// pack writes each value in its smallest form: an integer as a fixint or
// the smallest int 8 to 64, a double as float 64, a string as a str, data
// as a bin, a date as a timestamp (-1) extension, 64 bits where the seconds
// fit 34, else 96, an ext as it is, which holds its whole encoding, an
// array and a dictionary by their counts. unpack reads every format, uint
// included, a float 32 as a double, a timestamp as a date, another ext as
// an ext holding its encoding, and gives error("...") for bytes that are
// not MessagePack, an uint 64 past an i64 among them, as swift-sion does.
#import <SION>
#import <math.h> as C
#import <string.h> as C

struct MsgPack { packed: Bytes }   // a name to call the functions by: MsgPack.pack, MsgPack.unpack

struct MsgPackReader { at:const Bytes^; i: i64 }

extend MsgPack {
    // ---------- packing ----------

    static let put(var out:Bytes^, v:u64, bytes:i64):() {
        var k:i64 = bytes - 1
        while k >= 0 {
            out^ += ((v >> (k * 8)) & 0xFF) as u8
            k -= 1
        }
    }

    static let packInteger(var out:Bytes^, n:i64):() {
        if n >= -32 && n <= 127 {
            out^ += n as u8
        } else if n >= -128 && n <= 127 {
            out^ += 0xD0 as u8
            out^ += n as u8
        } else if n >= -32768 && n <= 32767 {
            out^ += 0xD1 as u8
            Self.put(out, n as u64, 2)
        } else if n >= -2147483648 && n <= 2147483647 {
            out^ += 0xD2 as u8
            Self.put(out, n as u64, 4)
        } else {
            out^ += 0xD3 as u8
            Self.put(out, n as u64, 8)
        }
    }

    // a count in its smallest form: in the fix byte where there is one,
    // else after the 8-, 16- or 32-bit code, -1 for a code a kind lacks
    static let packCount(var out:Bytes^, n:i64, fix:i64, fixMax:i64, c8:i64, c16:i64, c32:i64):() {
        if fix >= 0 && n <= fixMax {
            out^ += (fix | n) as u8
        } else if c8 >= 0 && n <= 0xFF {
            out^ += c8 as u8
            out^ += n as u8
        } else if n <= 0xFFFF {
            out^ += c16 as u8
            Self.put(out, n as u64, 2)
        } else {
            out^ += c32 as u8
            Self.put(out, n as u64, 4)
        }
    }

    static let write(v:const SION^, var out:Bytes^):() {
        switch v^ {
        case nil: out^ += 0xC0 as u8
        case boolean: out^ += (v^.boolean ? 0xC3 : 0xC2) as u8
        case integer: Self.packInteger(out, v^.integer)
        case number:
            var bits:u64 = 0
            let x = v^.number
            memcpy(&bits, &x, 8)
            out^ += 0xCB as u8
            Self.put(out, bits, 8)
        case string:
            let n = v^.string.bytes^.count as i64
            Self.packCount(out, n, 0xA0, 31, 0xD9, 0xDA, 0xDB)
            out^ += v^.string.bytes
        case error:
            let n = v^.error.bytes^.count as i64
            Self.packCount(out, n, 0xA0, 31, 0xD9, 0xDA, 0xDB)
            out^ += v^.error.bytes
        case data:
            Self.packCount(out, v^.data.count as i64, -1, -1, 0xC4, 0xC5, 0xC6)
            out^ += &v^.data
        case ext: out^ += &v^.ext
        case date:
            let t = v^.date
            let sec:f64 = floor(t)
            var nsec:i64 = ((t - sec) * 1e9) as i64
            if nsec > 999999999 { nsec = 999999999 }
            if sec >= 0.0 && sec < 17179869184.0 {   // 2^34: timestamp 64
                out^ += 0xD7 as u8
                out^ += 0xFF as u8
                Self.put(out, ((nsec as u64) << 34) | (sec as i64 as u64), 8)
            } else {                                // timestamp 96
                out^ += 0xC7 as u8
                out^ += 12 as u8
                out^ += 0xFF as u8
                Self.put(out, nsec as u64, 4)
                Self.put(out, sec as i64 as u64, 8)
            }
        case array:
            Self.packCount(out, v^.array.count as i64, 0x90, 15, -1, 0xDC, 0xDD)
            for x in v^.array { Self.write(&x, out) }
        case dictionary:
            Self.packCount(out, v^.dictionary.count as i64 / 2, 0x80, 15, -1, 0xDE, 0xDF)
            for x in v^.dictionary { Self.write(&x, out) }
        }
    }

    static let pack(v:const SION^):Bytes {
        var out = Bytes()
        Self.write(v, &out)
        return out
    }

    // ---------- unpacking ----------

    static let fail(what:cstr, at:i64):SION { SION.error($`${what} at ${at}`) }

    // the next n bytes as an unsigned number, big-endian; -1 past the end
    static let take(var r:MsgPackReader^, n:i64, var v:u64^):bool {
        if r^.i + n > r^.at^.count as i64 { return false }
        v^ = 0
        for k in 0..<n {
            v^ = (v^ << 8) | (r^.at^[r^.i + k] as u64)
        }
        r^.i += n
        return true
    }

    // n bytes as a string, data, or an ext's whole encoding from start
    static let bytes(var r:MsgPackReader^, from:i64, n:i64, var out:Bytes^):bool {
        if from + n > r^.at^.count as i64 { return false }
        for k in from..<(from + n) { out^ += r^.at^[k] }
        r^.i = from + n
        return true
    }

    static let readString(var r:MsgPackReader^, n:i64):SION {
        var b = Bytes()
        if !Self.bytes(r, r^.i, n, &b) { return Self.fail("a string ends past the bytes", r^.i) }
        if !b.isUTF8 { return Self.fail("a string is not UTF-8", r^.i) }
        return SION.string(String(&b))
    }

    static let readData(var r:MsgPackReader^, n:i64):SION {
        var b = Bytes()
        if !Self.bytes(r, r^.i, n, &b) { return Self.fail("data ends past the bytes", r^.i) }
        return SION.data(b)
    }

    // an ext of n data bytes whose header starts at start: a timestamp as
    // a date, any other as an ext holding the whole encoding
    static let readExt(var r:MsgPackReader^, start:i64, n:i64):SION {
        if r^.i >= r^.at^.count as i64 { return Self.fail("an ext ends past the bytes", r^.i) }
        let kind = r^.at^[r^.i]
        if kind == 0xFF {
            var v:u64 = 0
            if n == 4 {
                r^.i += 1
                if !Self.take(r, 4, &v) { return Self.fail("a timestamp ends past the bytes", r^.i) }
                return SION.date(f64(v))
            }
            if n == 8 {
                r^.i += 1
                if !Self.take(r, 8, &v) { return Self.fail("a timestamp ends past the bytes", r^.i) }
                return SION.date(f64(v & 0x3FFFFFFFF) + f64(v >> 34) / 1e9)
            }
            if n == 12 {
                r^.i += 1
                var nsec:u64 = 0
                if !Self.take(r, 4, &nsec) || !Self.take(r, 8, &v) { return Self.fail("a timestamp ends past the bytes", r^.i) }
                return SION.date(f64(v as i64) + f64(nsec) / 1e9)
            }
        }
        var b = Bytes()
        if !Self.bytes(r, start, r^.i + 1 + n - start, &b) { return Self.fail("an ext ends past the bytes", r^.i) }
        return SION.ext(b)
    }

    static let readValue(var r:MsgPackReader^):SION

    static let readArray(var r:MsgPackReader^, n:i64):SION {
        var a:Array<SION> = Array<SION>()
        for k in 0..<n {
            a += Self.readValue(r)
            if a[a.count - 1].is(error) { return SION.error(a[a.count - 1].error.copy()) }
        }
        return SION.array(a)
    }

    static let readMap(var r:MsgPackReader^, n:i64):SION {
        var d:Array<SION> = Array<SION>()
        for k in 0..<(2 * n) {
            d += Self.readValue(r)
            if d[d.count - 1].is(error) { return SION.error(d[d.count - 1].error.copy()) }
        }
        return SION.dictionary(d)
    }

    static let readValue(var r:MsgPackReader^):SION {
        let start = r^.i
        if r^.i >= r^.at^.count as i64 { return Self.fail("a value ends past the bytes", r^.i) }
        let c = r^.at^[r^.i]
        r^.i += 1
        var v:u64 = 0
        if c <= 0x7F { return SION.integer(c as i64) }
        if c >= 0xE0 { return SION.integer(c as i64 - 256) }
        if c >= 0xA0 && c <= 0xBF { return Self.readString(r, (c & 0x1F) as i64) }
        if c >= 0x90 && c <= 0x9F { return Self.readArray(r, (c & 0x0F) as i64) }
        if c >= 0x80 && c <= 0x8F { return Self.readMap(r, (c & 0x0F) as i64) }
        if c == 0xC0 { return SION.nil }
        if c == 0xC2 { return SION.boolean(false) }
        if c == 0xC3 { return SION.boolean(true) }
        if c == 0xCC || c == 0xCD || c == 0xCE || c == 0xCF {
            let n:i64 = c == 0xCC ? 1 : c == 0xCD ? 2 : c == 0xCE ? 4 : 8
            if !Self.take(r, n, &v) { return Self.fail("an integer ends past the bytes", r^.i) }
            if v > 9223372036854775807 { return Self.fail("an uint 64 past an i64", start) }
            return SION.integer(v as i64)
        }
        if c == 0xD0 || c == 0xD1 || c == 0xD2 || c == 0xD3 {
            let n:i64 = c == 0xD0 ? 1 : c == 0xD1 ? 2 : c == 0xD2 ? 4 : 8
            if !Self.take(r, n, &v) { return Self.fail("an integer ends past the bytes", r^.i) }
            let shift:i64 = 64 - 8 * n
            return SION.integer(((v << shift) as i64) >> shift)   // sign-extended
        }
        if c == 0xCA {
            if !Self.take(r, 4, &v) { return Self.fail("a float ends past the bytes", r^.i) }
            var bits:u32 = v as u32
            var x:f32 = 0.0
            memcpy(&x, &bits, 4)
            return SION.number(f64(x))
        }
        if c == 0xCB {
            if !Self.take(r, 8, &v) { return Self.fail("a double ends past the bytes", r^.i) }
            var x:f64 = 0.0
            memcpy(&x, &v, 8)
            return SION.number(x)
        }
        if c == 0xD9 || c == 0xDA || c == 0xDB {
            if !Self.take(r, c == 0xD9 ? 1 : c == 0xDA ? 2 : 4, &v) { return Self.fail("a string's count ends past the bytes", r^.i) }
            return Self.readString(r, v as i64)
        }
        if c == 0xC4 || c == 0xC5 || c == 0xC6 {
            if !Self.take(r, c == 0xC4 ? 1 : c == 0xC5 ? 2 : 4, &v) { return Self.fail("data's count ends past the bytes", r^.i) }
            return Self.readData(r, v as i64)
        }
        if c == 0xDC || c == 0xDD {
            if !Self.take(r, c == 0xDC ? 2 : 4, &v) { return Self.fail("an array's count ends past the bytes", r^.i) }
            return Self.readArray(r, v as i64)
        }
        if c == 0xDE || c == 0xDF {
            if !Self.take(r, c == 0xDE ? 2 : 4, &v) { return Self.fail("a map's count ends past the bytes", r^.i) }
            return Self.readMap(r, v as i64)
        }
        if c >= 0xD4 && c <= 0xD8 {
            let n:i64 = c == 0xD4 ? 1 : c == 0xD5 ? 2 : c == 0xD6 ? 4 : c == 0xD7 ? 8 : 16
            return Self.readExt(r, start, n)
        }
        if c == 0xC7 || c == 0xC8 || c == 0xC9 {
            if !Self.take(r, c == 0xC7 ? 1 : c == 0xC8 ? 2 : 4, &v) { return Self.fail("an ext's count ends past the bytes", r^.i) }
            return Self.readExt(r, start, v as i64)
        }
        return Self.fail("not a MessagePack format byte", start)
    }

    static let unpack(b:const Bytes^):SION {
        var r:MsgPackReader = {b, 0}
        var v = Self.readValue(&r)
        if !v.is(error) && r.i < b^.count as i64 { return Self.fail("bytes after the value", r.i) }
        return v
    }
}
