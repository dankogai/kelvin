// modules/BigInt.k - integers of any size (#507), the prelude's, after Python's
// int and JS's BigInt, written in Kelvin after swift-bignum's algorithms: two's
// complement in little-endian u64 limbs, the top bit repeated to the left,
// kept as short as it can be; zero is no limbs and -1 one limb of all ones.
// Built by kelvinc --prelude into BigInt.kh and an object that libkelvin
// holds; a program that names BigInt has it with no import.
//
//     let f = BigInt(1) << 100                    // 1267650600228229401496703205376
//     var n = BigInt("123456789012345678901234567890")
//     println(n * n + 1, " ", n / 7, " ", n % 7, " ", n.text(16), " ", -n >> 3)
#import <stdio.h> as C
#import <math.h> as C

struct BigInt {
    limbs: $[u64]
}

// the runtime's end of a failed check, after its message (#174); and
// kv_array_fail, the message and the end together, the prelude header's
let kv_exit_failure():()

// ---------- limbs, two's complement ----------

let kv_bi_ones():u64 { ~(0 as u64) }

// whether the limbs l are of a negative value: its top bit set
let kv_bi_negative(l:const $[u64]^):bool { l^.count > 0 && (l^[l^.count - 1] >> 63) == 1 }

// limb i of l, past its top the sign repeated
let kv_bi_limb(l:const $[u64]^, i:i64):u64 {
    if i < l^.count as i64 { return l^[i] }
    return kv_bi_negative(l) ? kv_bi_ones() : 0
}

// l without the top limbs that only repeat the sign
let kv_bi_norm(var l:$[u64]):$[u64] {
    var more = true
    while more && l.count > 0 {
        let top:u64 = l[l.count - 1]
        if l.count == 1 {
            if top == 0 { l.pop() }
            more = false
        } else {
            let below:u64 = l[l.count - 2] >> 63
            if (top == 0 && below == 0) || (top == kv_bi_ones() && below == 1) {
                l.pop()
            } else {
                more = false
            }
        }
    }
    return l
}

// l without its top zero limbs, an unsigned magnitude's form
let kv_bi_strip(var l:$[u64]):$[u64] {
    while l.count > 0 && l[l.count - 1] == 0 { l.pop() }
    return l
}

let kv_bi_add(a:const $[u64]^, b:const $[u64]^):$[u64] {
    let n:i64 = (a^.count > b^.count ? a^.count : b^.count) as i64 + 1
    var r:$[u64] = $[]
    var carry:u64 = 0
    for i in 0..<n {
        let x:u64 = kv_bi_limb(a, i)
        let s:u64 = x + kv_bi_limb(b, i)
        let t:u64 = s + carry
        carry = (s < x ? 1 : 0) + (t < s ? 1 : 0)
        r += t
    }
    return kv_bi_norm(r)
}

let kv_bi_neg(a:const $[u64]^):$[u64] {
    let n:i64 = a^.count as i64 + 1
    var r:$[u64] = $[]
    var carry:u64 = 1
    for i in 0..<n {
        let x:u64 = ~kv_bi_limb(a, i)
        let t:u64 = x + carry
        carry = t < x ? 1 : 0
        r += t
    }
    return kv_bi_norm(r)
}

let kv_bi_sub(a:const $[u64]^, b:const $[u64]^):$[u64] {
    let nb = kv_bi_neg(b)
    return kv_bi_add(a, &nb)
}

// -1, 0 or 1 as a is below, at or above b
let kv_bi_cmp(a:const $[u64]^, b:const $[u64]^):i64 {
    let na = kv_bi_negative(a)
    let nb = kv_bi_negative(b)
    if na != nb { return na ? 0 - 1 : 1 }
    var i:i64 = (a^.count > b^.count ? a^.count : b^.count) as i64 - 1
    while i >= 0 {
        let x:u64 = kv_bi_limb(a, i)
        let y:u64 = kv_bi_limb(b, i)
        if x != y { return x < y ? 0 - 1 : 1 }
        i -= 1
    }
    return 0
}

// the magnitude of a, unsigned limbs with no top zeros
let kv_bi_mag(a:const $[u64]^):$[u64] {
    if kv_bi_negative(a) { return kv_bi_strip(kv_bi_neg(a)) }
    var r:$[u64] = $[]
    for x in a^ { r += x }
    return kv_bi_strip(r)
}

// the value of the magnitude m with a sign
let kv_bi_signed(var m:$[u64], negative:bool):$[u64] {
    m = kv_bi_strip(m)
    if m.count > 0 && (m[m.count - 1] >> 63) == 1 { m += 0 }   // a sign limb above a full top limb
    if negative && m.count > 0 { m = kv_bi_neg(&m) }
    return kv_bi_norm(m)
}

// ---------- magnitudes: multiplication and division ----------

// the limbs of the magnitude a from lo up to hi, no top zeros
let kv_bi_slice(a:const $[u64]^, lo:i64, hi:i64):$[u64] {
    var r:$[u64] = $[]
    var i:i64 = lo
    while i < hi && i < a^.count as i64 {
        r += a^[i]
        i += 1
    }
    return kv_bi_strip(r)
}

// the magnitudes a + b
let kv_bi_uadd(a:const $[u64]^, b:const $[u64]^):$[u64] {
    let n:i64 = (a^.count > b^.count ? a^.count : b^.count) as i64
    var r:$[u64] = $[]
    var carry:u64 = 0
    for i in 0..<n {
        let x:u64 = i < a^.count as i64 ? a^[i] : 0
        let s:u64 = x + (i < b^.count as i64 ? b^[i] : 0)
        let t:u64 = s + carry
        carry = (s < x ? 1 : 0) + (t < s ? 1 : 0)
        r += t
    }
    if carry != 0 { r += carry }
    return r
}

// the magnitudes a - b, where a is b or more
let kv_bi_usub(a:const $[u64]^, b:const $[u64]^):$[u64] {
    var r:$[u64] = $[]
    var borrow:u64 = 0
    for i in 0..<(a^.count as i64) {
        let x:u64 = a^[i]
        let y:u64 = i < b^.count as i64 ? b^[i] : 0
        let t:u64 = x - y
        let u:u64 = t - borrow
        borrow = (x < y ? 1 : 0) + (t < borrow ? 1 : 0)
        r += u
    }
    return kv_bi_strip(r)
}

// r += a, shifted up k limbs, in place; r has room
let kv_bi_add_at(r:$[u64]^, a:const $[u64]^, k:i64):() {
    var carry:u64 = 0
    var i:i64 = 0
    while i < a^.count as i64 || carry != 0 {
        let x:u64 = r^[k + i]
        let s:u64 = x + (i < a^.count as i64 ? a^[i] : 0)
        let t:u64 = s + carry
        carry = (s < x ? 1 : 0) + (t < s ? 1 : 0)
        r^[k + i] = t
        i += 1
    }
}

// the magnitudes a * b, by Karatsuba's three halves past 40 limbs each,
// as swift-bignum, else the schoolbook's
let kv_bi_umul(a:const $[u64]^, b:const $[u64]^):$[u64] {
    if a^.count >= 40 && b^.count >= 40 {
        let k:i64 = ((a^.count > b^.count ? a^.count : b^.count) as i64 + 1) / 2
        let a0 = kv_bi_slice(a, 0, k)
        let a1 = kv_bi_slice(a, k, a^.count as i64)
        let b0 = kv_bi_slice(b, 0, k)
        let b1 = kv_bi_slice(b, k, b^.count as i64)
        let z0 = kv_bi_umul(&a0, &b0)
        let z2 = kv_bi_umul(&a1, &b1)
        let sa = kv_bi_uadd(&a0, &a1)
        let sb = kv_bi_uadd(&b0, &b1)
        let z1a = kv_bi_umul(&sa, &sb)
        let z1b = kv_bi_usub(&z1a, &z0)
        let z1 = kv_bi_usub(&z1b, &z2)
        var r = Array<u64>(a^.count + b^.count + 1)
        kv_bi_add_at(&r, &z0, 0)
        kv_bi_add_at(&r, &z1, k)
        kv_bi_add_at(&r, &z2, 2 * k)
        return kv_bi_strip(r)
    }
    return kv_bi_school(a, b)
}

let kv_bi_school(a:const $[u64]^, b:const $[u64]^):$[u64] {
    if a^.count == 0 || b^.count == 0 { return Array<u64>() }
    var r = Array<u64>(a^.count + b^.count)
    for i in 0..<a^.count as i64 {
        var carry:u64 = 0
        let x:u128 = a^[i] as u128
        for j in 0..<b^.count as i64 {
            let t:u128 = x * (b^[j] as u128) + (r[i + j] as u128) + (carry as u128)
            r[i + j] = t as u64
            carry = (t >> 64) as u64
        }
        r[i + b^.count as i64] = carry
    }
    return kv_bi_strip(r)
}

// the magnitude a divided by the limb d, the remainder into rem
let kv_bi_udiv1(a:const $[u64]^, d:u64, rem:u64^):$[u64] {
    var q = Array<u64>(a^.count)
    var r:u128 = 0
    var i:i64 = a^.count as i64 - 1
    while i >= 0 {
        let cur:u128 = (r << 64) | (a^[i] as u128)
        q[i] = (cur / (d as u128)) as u64
        r = cur % (d as u128)
        i -= 1
    }
    rem^ = r as u64
    return kv_bi_strip(q)
}

// the leading zero bits of x, which is not 0
let kv_bi_clz(x:u64):i64 {
    var n:i64 = 0
    var y:u64 = x
    while (y >> 63) == 0 {
        y = y << 1
        n += 1
    }
    return n
}

// the magnitude u divided by the magnitude v, of two limbs or more: Knuth's
// algorithm D, with u128 for two limbs; the quotient into q, the remainder
// into r
let kv_bi_udivmod(u:const $[u64]^, v:const $[u64]^, q:$[u64]^, r:$[u64]^):() {
    let n:i64 = v^.count as i64
    if u^.count < v^.count || kv_bi_cmp_mag(u, v) < 0 {
        q^ = Array<u64>()
        var c:$[u64] = $[]
        for x in u^ { c += x }
        r^ = kv_bi_strip(c)
        return
    }
    let m:i64 = u^.count as i64 - n
    let s:i64 = kv_bi_clz(v^[n - 1])
    var vn = Array<u64>(n)
    var un = Array<u64>(u^.count + 1)
    for i in 0..<n {
        let lo:u64 = v^[i] << s
        let carry:u64 = s > 0 && i > 0 ? v^[i - 1] >> (64 - s) : 0
        vn[i] = lo | carry
    }
    for i in 0..<(u^.count as i64) {
        let lo:u64 = u^[i] << s
        let carry:u64 = s > 0 && i > 0 ? u^[i - 1] >> (64 - s) : 0
        un[i] = lo | carry
    }
    un[u^.count] = s > 0 ? u^[u^.count - 1] >> (64 - s) : 0
    var qs = Array<u64>(m + 1)
    let base:u128 = (1 as u128) << 64
    let mask:u128 = base - 1
    var j:i64 = m
    while j >= 0 {
        let num:u128 = ((un[j + n] as u128) << 64) | (un[j + n - 1] as u128)
        var qhat:u128 = num / (vn[n - 1] as u128)
        var rhat:u128 = num % (vn[n - 1] as u128)
        while qhat >= base || qhat * (vn[n - 2] as u128) > ((rhat << 64) | (un[j + n - 2] as u128)) {
            qhat -= 1
            rhat += vn[n - 1] as u128
            if rhat >= base { break }
        }
        var k:i128 = 0
        for i in 0..<n {
            let p:u128 = qhat * (vn[i] as u128)
            let t:i128 = (un[i + j] as i128) - k - ((p & mask) as i128)
            un[i + j] = t as u64
            k = ((p >> 64) as i128) - (t >> 64)
        }
        let t:i128 = (un[j + n] as i128) - k
        un[j + n] = t as u64
        qs[j] = qhat as u64
        if t < 0 {
            qs[j] = qs[j] - 1
            var c:u128 = 0
            for i in 0..<n {
                let w:u128 = (un[i + j] as u128) + (vn[i] as u128) + c
                un[i + j] = w as u64
                c = w >> 64
            }
            un[j + n] = un[j + n] + (c as u64)
        }
        j -= 1
    }
    var rs = Array<u64>(n)
    for i in 0..<n {
        let lo:u64 = s > 0 ? un[i] >> s : un[i]
        let hi:u64 = s > 0 ? un[i + 1] << (64 - s) : 0
        rs[i] = lo | hi
    }
    q^ = kv_bi_strip(qs)
    r^ = kv_bi_strip(rs)
}

// -1, 0 or 1 as the magnitude a is below, at or above the magnitude b
let kv_bi_cmp_mag(a:const $[u64]^, b:const $[u64]^):i64 {
    if a^.count != b^.count { return a^.count < b^.count ? 0 - 1 : 1 }
    var i:i64 = a^.count as i64 - 1
    while i >= 0 {
        if a^[i] != b^[i] { return a^[i] < b^[i] ? 0 - 1 : 1 }
        i -= 1
    }
    return 0
}

let kv_bi_zero_division():() {
    fprintf(stderr, "kelvin: division of a BigInt by zero\n")
    kv_exit_failure()
}

// a divided by b, truncated toward zero as Kelvin's integers are, into q,
// and the remainder, of a's sign, into r
let kv_bi_divmod(a:const $[u64]^, b:const $[u64]^, q:$[u64]^, r:$[u64]^):() {
    if b^.count == 0 { kv_bi_zero_division() }
    let ma = kv_bi_mag(a)
    let mb = kv_bi_mag(b)
    var mq:$[u64] = $[]
    var mr:$[u64] = $[]
    if mb.count == 1 {
        var rem:u64 = 0
        mq = kv_bi_udiv1(&ma, mb[0], &rem)
        if rem != 0 { mr += rem }
    } else {
        kv_bi_udivmod(&ma, &mb, &mq, &mr)
    }
    let na = kv_bi_negative(a)
    q^ = kv_bi_signed(mq, na != kv_bi_negative(b))
    r^ = kv_bi_signed(mr, na)
}

// ---------- bits ----------

// a op b limb by limb: 0 and, 1 or, 2 xor
let kv_bi_bits(a:const $[u64]^, b:const $[u64]^, op:i64):$[u64] {
    let n:i64 = (a^.count > b^.count ? a^.count : b^.count) as i64
    var r:$[u64] = $[]
    for i in 0..<n {
        let x:u64 = kv_bi_limb(a, i)
        let y:u64 = kv_bi_limb(b, i)
        r += op == 0 ? x & y : op == 1 ? x | y : x ~ y
    }
    return kv_bi_norm(r)
}

let kv_bi_not(a:const $[u64]^):$[u64] {
    var r:$[u64] = $[]
    for x in a^ { r += ~x }
    if r.count == 0 { r += kv_bi_ones() }
    return kv_bi_norm(r)
}

let kv_bi_shl(a:const $[u64]^, k:i64):$[u64] {
    let w:i64 = k / 64
    let b:i64 = k % 64
    var r:$[u64] = $[]
    for i in 0..<w { r += 0 }
    var prev:u64 = 0
    for x in a^ {
        r += b > 0 ? (x << b) | (prev >> (64 - b)) : x
        prev = x
    }
    let ext:u64 = kv_bi_negative(a) ? kv_bi_ones() : 0
    r += b > 0 ? (ext << b) | (prev >> (64 - b)) : ext
    return kv_bi_norm(r)
}

// a shifted right k bits, the sign kept: a divided by 2 ** k, rounded down
let kv_bi_shr(a:const $[u64]^, k:i64):$[u64] {
    let w:i64 = k / 64
    let b:i64 = k % 64
    var r:$[u64] = $[]
    for i in w..<(a^.count as i64) {
        let lo:u64 = kv_bi_limb(a, i)
        let hi:u64 = kv_bi_limb(a, i + 1)
        r += b > 0 ? (lo >> b) | (hi << (64 - b)) : lo
    }
    r += kv_bi_negative(a) ? kv_bi_ones() : 0          // all of it shifted out: 0, or -1 of a negative one
    return kv_bi_norm(r)
}

// ---------- text ----------

let kv_bi_digits():cstr { "0123456789abcdefghijklmnopqrstuvwxyz" }

let kv_bi_bad_base(base:i64):() {
    fprintf(stderr, "kelvin: a BigInt's text has a base from 2 to 36, and this is %lld\n", base)
    kv_exit_failure()
}

// the text of a in base, its digits lowercase, a '-' before a negative one
let kv_bi_text(a:const $[u64]^, base:i64):String {
    if base < 2 || base > 36 { kv_bi_bad_base(base) }
    if a^.count == 0 { return $"0" }
    var chunk:u64 = base as u64                          // the largest power of base in a limb, and its digits
    var width:i64 = 1
    while chunk <= kv_bi_ones() / (base as u64) {
        chunk = chunk * (base as u64)
        width += 1
    }
    var m = kv_bi_mag(a)
    var parts:$[u64] = $[]
    while m.count > 0 {
        var rem:u64 = 0
        m = kv_bi_udiv1(&m, chunk, &rem)
        parts += rem
    }
    var out = Bytes()
    if kv_bi_negative(a) { out += '-' as u8 }
    let digits := kv_bi_digits()
    var i:i64 = parts.count as i64 - 1
    while i >= 0 {
        var v:u64 = parts[i]
        var here = Array<u8>(width)
        var k:i64 = width - 1
        while k >= 0 {
            here[k] = digits[v % (base as u64)]
            v = v / (base as u64)
            k -= 1
        }
        var from:i64 = 0
        if i == parts.count as i64 - 1 {
            while from < width - 1 && here[from] == '0' as u8 { from += 1 }
        }
        for d in from..<width { out += here[d] }
        i -= 1
    }
    return out.string() ?? $""
}

// a's text as a literal, which reads back as a (#509): a sign, the prefix of
// the base, its digits and an n, +0xffn
let kv_bi_prefixed(a:const $[u64]^, base:i64, prefix:cstr):String {
    let m = kv_bi_mag(a)
    var s = String(kv_bi_negative(a) ? "-" : "+")
    s += prefix
    s += kv_bi_text(&m, base)
    s += "n"
    return s
}

// the value of a digit in base, or -1
let kv_bi_digit(c:u8, base:i64):i64 {
    var v:i64 = 0 - 1
    if c >= '0' as u8 && c <= '9' as u8 { v = (c - ('0' as u8)) as i64 }
    if c >= 'a' as u8 && c <= 'z' as u8 { v = (c - ('a' as u8)) as i64 + 10 }
    if c >= 'A' as u8 && c <= 'Z' as u8 { v = (c - ('A' as u8)) as i64 + 10 }
    return v < base ? v : 0 - 1
}

// the magnitude m times f plus a, in place
let kv_bi_mul_add(m:$[u64]^, f:u64, a:u64):() {
    var carry:u128 = a as u128
    for i in 0..<(m^.count as i64) {
        let t:u128 = (m^[i] as u128) * (f as u128) + carry
        m^[i] = t as u64
        carry = t >> 64
    }
    if carry != 0 { m^ += carry as u64 }
}

// text read as i64(s) reads it, strtol's way: spaces, a sign, a 0x before
// base 16's digits, 0o before 8's and 0b before 2's, then the longest run
// of digits, so that the n after them ends it; 0 for none
let kv_bi_parse(s:cstr, base:i64):$[u64] {
    var m:$[u64] = $[]
    if base < 2 || base > 36 { return Array<u64>() }
    var i:i64 = 0
    while s[i] == ' ' as u8 || (s[i] >= 9 && s[i] <= 13) { i += 1 }
    var negative = false
    if s[i] == '+' as u8 || s[i] == '-' as u8 {
        negative = s[i] == '-' as u8
        i += 1
    }
    let mark:u8 = base == 16 ? 'x' as u8 : base == 8 ? 'o' as u8 : base == 2 ? 'b' as u8 : 0
    if mark != 0 && s[i] == '0' as u8 && (s[i + 1] == mark || s[i + 1] == mark - 32) && kv_bi_digit(s[i + 2], base) >= 0 {
        i += 2                                           // 0x of base 16, 0o of 8 and 0b of 2, as i64(s, base) reads them
    }
    var chunk:u64 = 0
    var scale:u64 = 1
    while s[i] != 0 && kv_bi_digit(s[i], base) >= 0 {
        chunk = chunk * (base as u64) + (kv_bi_digit(s[i], base) as u64)
        scale = scale * (base as u64)
        if scale > kv_bi_ones() / (base as u64) {
            kv_bi_mul_add(&m, scale, chunk)
            chunk = 0
            scale = 1
        }
        i += 1
    }
    if scale > 1 { kv_bi_mul_add(&m, scale, chunk) }
    return kv_bi_signed(m, negative)
}

// ---------- powers, gcd, square roots ----------

// the magnitude m squared and multiplied: m ** e
let kv_bi_upow(m:const $[u64]^, e:u64):$[u64] {
    var r:$[u64] = $[]
    r += 1
    var x = kv_bi_strip(kv_bi_slice(m, 0, m^.count as i64))
    var k:u64 = e
    while k > 0 {
        if (k & 1) == 1 { r = kv_bi_umul(&r, &x) }
        k = k >> 1
        if k > 0 { x = kv_bi_umul(&x, &x) }
    }
    return r
}

// a ** e, an exponent of 0 or more
let kv_bi_pow(a:const $[u64]^, e:i64):$[u64] {
    if e < 0 { kv_array_fail("'**' of a BigInt takes an exponent of 0 or more") }
    let m = kv_bi_mag(a)
    let p = kv_bi_upow(&m, e as u64)
    return kv_bi_signed(p, kv_bi_negative(a) && (e & 1) == 1)
}

// a mod n, n a positive value: 0 or more, below n
let kv_bi_floor_mod(a:const $[u64]^, n:const $[u64]^):$[u64] {
    var q:$[u64] = $[]
    var r:$[u64] = $[]
    kv_bi_divmod(a, n, &q, &r)
    if kv_bi_negative(&r) { r = kv_bi_add(&r, n) }
    return r
}

// the inverse of a mod n, n positive, by Euclid's algorithm extended;
// one that shares a factor with n ends the program, as Python raises
let kv_bi_inverse(a:const $[u64]^, n:const $[u64]^):$[u64] {
    var r0 = kv_bi_slice(n, 0, n^.count as i64)
    var r1 = kv_bi_floor_mod(a, n)
    var t0:$[u64] = $[]
    var t1:$[u64] = $[]
    t1 += 1
    while r1.count > 0 {
        var q:$[u64] = $[]
        var r2:$[u64] = $[]
        kv_bi_divmod(&r0, &r1, &q, &r2)
        let qt = kv_bi_mul(&q, &t1)
        let t2 = kv_bi_sub(&t0, &qt)
        r0 = r1.copy()
        r1 = r2.copy()
        t0 = t1.copy()
        t1 = t2.copy()
    }
    if !(r0.count == 1 && r0[0] == 1) {
        kv_array_fail("'.pow(e, m)' of a negative e takes the inverse of b mod m, and b has none: b and m share a factor")
    }
    return kv_bi_floor_mod(&t0, n)
}

// a * b of two values, the sign by theirs
let kv_bi_mul(a:const $[u64]^, b:const $[u64]^):$[u64] {
    let ma = kv_bi_mag(a)
    let mb = kv_bi_mag(b)
    let p = kv_bi_umul(&ma, &mb)
    return kv_bi_signed(p, kv_bi_negative(a) != kv_bi_negative(b))
}

// b to the e, mod m, as Python's pow(b, e, m): the result takes m's sign; a
// negative e raises b's inverse mod m; m of 0 ends the program
let kv_bi_powmod(b:const $[u64]^, e:const $[u64]^, m:const $[u64]^):$[u64] {
    if m^.count == 0 { kv_array_fail("'.pow(e, m)' takes a modulus other than 0") }
    let n = kv_bi_signed(kv_bi_mag(m), false)
    var x = kv_bi_floor_mod(b, &n)
    if kv_bi_negative(e) { x = kv_bi_inverse(&x, &n) }
    let k = kv_bi_mag(e)
    var r:$[u64] = $[]
    r += 1
    r = kv_bi_floor_mod(&r, &n)
    for i in 0..<(k.count as i64 * 64) {
        if ((k[i / 64] >> (i % 64)) & 1) == 1 {
            let p = kv_bi_mul(&r, &x)
            r = kv_bi_floor_mod(&p, &n)
        }
        let s = kv_bi_mul(&x, &x)
        x = kv_bi_floor_mod(&s, &n)
    }
    if kv_bi_negative(m) && r.count > 0 { r = kv_bi_sub(&r, &n) }
    return r
}

// the greatest common divisor of a and b, 0 or more, by Euclid's
let kv_bi_gcd(a:const $[u64]^, b:const $[u64]^):$[u64] {
    var x = kv_bi_signed(kv_bi_mag(a), false)
    var y = kv_bi_signed(kv_bi_mag(b), false)
    while y.count > 0 {
        var q:$[u64] = $[]
        var r:$[u64] = $[]
        kv_bi_divmod(&x, &y, &q, &r)
        x = y.copy()
        y = r.copy()
    }
    return x
}

// the floor of the square root of a, by Newton's, from a power of 2 above it
let kv_bi_isqrt(a:const $[u64]^):$[u64] {
    if kv_bi_negative(a) { kv_array_fail("'.isqrt()' of a negative BigInt has none") }
    if a^.count == 0 { return Array<u64>() }
    let m = kv_bi_mag(a)
    let bits:i64 = (m.count as i64) * 64 - kv_bi_clz(m[m.count - 1])
    var one:$[u64] = $[]
    one += 1
    var x = kv_bi_shl(&one, (bits + 1) / 2)
    var going = true
    while going {
        var q:$[u64] = $[]
        var r:$[u64] = $[]
        kv_bi_divmod(a, &x, &q, &r)
        let s = kv_bi_add(&x, &q)
        let y = kv_bi_shr(&s, 1)
        if kv_bi_cmp(&y, &x) < 0 {
            x = y.copy()
        } else {
            going = false
        }
    }
    return x
}

// ---------- the type ----------

// of any integer, an i64's and a u64's alike, as an i128 holds both
let BigInt(n:i128):BigInt {
    var l:$[u64] = $[]
    l += n as u64
    l += (n >> 64) as u64
    return (BigInt){kv_bi_norm(l)}
}

let BigInt(text:cstr):BigInt { (BigInt){kv_bi_parse(text, 10)} }
let BigInt(text:cstr, base:i64):BigInt { (BigInt){kv_bi_parse(text, base)} }
let BigInt(text:const String^):BigInt { (BigInt){kv_bi_parse(text^.cstr, 10)} }
let BigInt(text:const String^, base:i64):BigInt { (BigInt){kv_bi_parse(text^.cstr, base)} }

extend BigInt {
    let string:String {                                   // 123n, its literal, which reads back as it (#509)
        var s = kv_bi_text(&self.limbs, 10)
        s += "n"
        return s
    }
    let hex:String { kv_bi_prefixed(&self.limbs, 16, "0x") }
    let oct:String { kv_bi_prefixed(&self.limbs, 8, "0o") }
    let bin:String { kv_bi_prefixed(&self.limbs, 2, "0b") }
    let text(base:i64):String { kv_bi_text(&self.limbs, base) }
    let isZero:bool { self.limbs.count == 0 }
    let isNegative:bool { kv_bi_negative(&self.limbs) }
    let sign:i64 { self.limbs.count == 0 ? 0 : kv_bi_negative(&self.limbs) ? 0 - 1 : 1 }
    let exactI64:i64? {                                  // where it fits, else none (#510)
        if self.limbs.count > 1 { return none }
        return kv_bi_limb(&self.limbs, 0) as i64
    }
    let exactU64:u64? {
        if kv_bi_negative(&self.limbs) || self.limbs.count > 2 || (self.limbs.count == 2 && self.limbs[1] != 0) { return none }
        return kv_bi_limb(&self.limbs, 0)
    }
    let pow(e:i64):BigInt { (BigInt){kv_bi_pow(&self.limbs, e)} }
    let pow(e:i64, m:i64):BigInt { pow(self, BigInt(e), BigInt(m)) }
    let pow(e:i64, m:lent BigInt):BigInt { pow(self, BigInt(e), m) }
    let pow(e:lent BigInt, m:i64):BigInt { pow(self, e, BigInt(m)) }
    let pow(e:lent BigInt, m:lent BigInt):BigInt { pow(self, e, m) }
    let gcd(b:lent BigInt):BigInt { (BigInt){kv_bi_gcd(&self.limbs, &b.limbs)} }
    let gcd(b:i64):BigInt { self.gcd(BigInt(b)) }
    let lcm(b:lent BigInt):BigInt {
        let g = kv_bi_gcd(&self.limbs, &b.limbs)
        if g.count == 0 { return BigInt(0) }
        let p = kv_bi_mul(&self.limbs, &b.limbs)
        var q:$[u64] = $[]
        var r:$[u64] = $[]
        kv_bi_divmod(&p, &g, &q, &r)
        return (BigInt){kv_bi_signed(kv_bi_mag(&q), false)}
    }
    let lcm(b:i64):BigInt { self.lcm(BigInt(b)) }
    let isqrt():BigInt { (BigInt){kv_bi_isqrt(&self.limbs)} }
    let abs:BigInt { (BigInt){kv_bi_signed(kv_bi_mag(&self.limbs), false)} }
    let i64:i64 { kv_bi_limb(&self.limbs, 0) as i64 }
    let u64:u64 { kv_bi_limb(&self.limbs, 0) }
    let f64:f64 {
        let m = kv_bi_mag(&self.limbs)
        var d:f64 = 0.0
        var i:i64 = m.count as i64 - 1
        while i >= 0 {
            d = d * 18446744073709551616.0 + (m[i] as f64)
            i -= 1
        }
        return kv_bi_negative(&self.limbs) ? 0.0 - d : d
    }

    static let +(a:Self, b:Self):Self { (Self){kv_bi_add(&a.limbs, &b.limbs)} }
    static let -(a:Self, b:Self):Self { (Self){kv_bi_sub(&a.limbs, &b.limbs)} }
    static let -(a:Self):Self { (Self){kv_bi_neg(&a.limbs)} }
    static let *(a:Self, b:Self):Self { (Self){kv_bi_mul(&a.limbs, &b.limbs)} }
    static let /(a:Self, b:Self):Self {
        var q:$[u64] = $[]
        var r:$[u64] = $[]
        kv_bi_divmod(&a.limbs, &b.limbs, &q, &r)
        return (Self){q}
    }
    static let %(a:Self, b:Self):Self {
        var q:$[u64] = $[]
        var r:$[u64] = $[]
        kv_bi_divmod(&a.limbs, &b.limbs, &q, &r)
        return (Self){r}
    }
    static let ==(a:Self, b:Self):bool { kv_bi_cmp(&a.limbs, &b.limbs) == 0 }
    static let !=(a:Self, b:Self):bool { kv_bi_cmp(&a.limbs, &b.limbs) != 0 }
    static let <(a:Self, b:Self):bool { kv_bi_cmp(&a.limbs, &b.limbs) < 0 }
    static let <=(a:Self, b:Self):bool { kv_bi_cmp(&a.limbs, &b.limbs) <= 0 }
    static let >(a:Self, b:Self):bool { kv_bi_cmp(&a.limbs, &b.limbs) > 0 }
    static let >=(a:Self, b:Self):bool { kv_bi_cmp(&a.limbs, &b.limbs) >= 0 }
    static let &(a:Self, b:Self):Self { (Self){kv_bi_bits(&a.limbs, &b.limbs, 0)} }
    static let |(a:Self, b:Self):Self { (Self){kv_bi_bits(&a.limbs, &b.limbs, 1)} }
    static let ~(a:Self, b:Self):Self { (Self){kv_bi_bits(&a.limbs, &b.limbs, 2)} }
    static let ~(a:Self):Self { (Self){kv_bi_not(&a.limbs)} }
    static let **(a:Self, e:i64):Self { (Self){kv_bi_pow(&a.limbs, e)} }
    static let **(a:Self, e:Self):Self {
        if e.limbs.count > 1 { kv_array_fail("'**' of a BigInt takes an exponent that fits in an i64") }
        return (Self){kv_bi_pow(&a.limbs, kv_bi_limb(&e.limbs, 0) as i64)}
    }
    static let <<(a:Self, k:i64):Self { (Self){k < 0 ? kv_bi_shr(&a.limbs, 0 - k) : kv_bi_shl(&a.limbs, k)} }
    static let >>(a:Self, k:i64):Self { (Self){k < 0 ? kv_bi_shl(&a.limbs, 0 - k) : kv_bi_shr(&a.limbs, k)} }

    // with an i64 on either side
    static let +(a:Self, b:i64):Self { a + BigInt(b) }
    static let +(a:i64, b:Self):Self { BigInt(a) + b }
    static let -(a:Self, b:i64):Self { a - BigInt(b) }
    static let -(a:i64, b:Self):Self { BigInt(a) - b }
    static let *(a:Self, b:i64):Self { a * BigInt(b) }
    static let *(a:i64, b:Self):Self { BigInt(a) * b }
    static let /(a:Self, b:i64):Self { a / BigInt(b) }
    static let /(a:i64, b:Self):Self { BigInt(a) / b }
    static let %(a:Self, b:i64):Self { a % BigInt(b) }
    static let %(a:i64, b:Self):Self { BigInt(a) % b }
    static let ==(a:Self, b:i64):bool { a == BigInt(b) }
    static let ==(a:i64, b:Self):bool { BigInt(a) == b }
    static let !=(a:Self, b:i64):bool { a != BigInt(b) }
    static let !=(a:i64, b:Self):bool { BigInt(a) != b }
    static let <(a:Self, b:i64):bool { a < BigInt(b) }
    static let <(a:i64, b:Self):bool { BigInt(a) < b }
    static let <=(a:Self, b:i64):bool { a <= BigInt(b) }
    static let <=(a:i64, b:Self):bool { BigInt(a) <= b }
    static let >(a:Self, b:i64):bool { a > BigInt(b) }
    static let >(a:i64, b:Self):bool { BigInt(a) > b }
    static let >=(a:Self, b:i64):bool { a >= BigInt(b) }
    static let >=(a:i64, b:Self):bool { BigInt(a) >= b }
    static let &(a:Self, b:i64):Self { a & BigInt(b) }
    static let &(a:i64, b:Self):Self { BigInt(a) & b }
    static let |(a:Self, b:i64):Self { a | BigInt(b) }
    static let |(a:i64, b:Self):Self { BigInt(a) | b }
    static let ~(a:Self, b:i64):Self { a ~ BigInt(b) }
    static let ~(a:i64, b:Self):Self { BigInt(a) ~ b }
}

// pow(b, e, m) of a BigInt, b.pow(e, m)'s, with a BigInt or an i64 in each
// place, one of them a BigInt (#510); C's pow of doubles beside them, as
// #223 asks, so that pow(2.0, 0.5) stays C's
let pow(x:f64, y:f64):f64
let pow(b:lent BigInt, e:lent BigInt, m:lent BigInt):BigInt { (BigInt){kv_bi_powmod(&b.limbs, &e.limbs, &m.limbs)} }
let pow(b:lent BigInt, e:lent BigInt, m:i64):BigInt { pow(b, e, BigInt(m)) }
let pow(b:lent BigInt, e:i64, m:lent BigInt):BigInt { pow(b, BigInt(e), m) }
let pow(b:lent BigInt, e:i64, m:i64):BigInt { pow(b, BigInt(e), BigInt(m)) }
let pow(b:i64, e:lent BigInt, m:lent BigInt):BigInt { pow(BigInt(b), e, m) }
let pow(b:i64, e:lent BigInt, m:i64):BigInt { pow(BigInt(b), e, BigInt(m)) }
let pow(b:i64, e:i64, m:lent BigInt):BigInt { pow(BigInt(b), BigInt(e), m) }
