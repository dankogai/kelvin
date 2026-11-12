// modules/BigInt.k - integers of any size (#507), the prelude's, after Python's
// int and JS's BigInt, written in Kelvin after swift-bignum's algorithms: two's
// complement in little-endian u64 limbs, the top bit repeated to the left,
// kept as short as it can be; zero is no limbs and -1 one limb of all ones.
// Built by kelvinc --prelude into BigInt.kh and an object that libkelvin
// holds; a program that names BigInt has it with no import.
//
// Its loops walk the limbs by pointers, a.at, unchecked, into results made
// at their size once (#518); a non-negative operand is read where it is,
// not copied into a magnitude.
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

// the limb that l's sign repeats past its top: all ones or 0
let kv_bi_ext(l:const $[u64]^):u64 { kv_bi_negative(l) ? kv_bi_ones() : 0 }

// limb i of l, past its top the sign repeated
let kv_bi_limb(l:const $[u64]^, i:i64):u64 {
    if i < l^.count as i64 { return l^[i] }
    return kv_bi_ext(l)
}

// l without the top limbs that only repeat the sign
let kv_bi_norm(var l:$[u64]):$[u64] {
    var n:i64 = l.count as i64
    let p:const u64^ := l.at
    while n > 0 {
        let top:u64 = p[n - 1]
        if n == 1 {
            if top == 0 { n = 0 }
            break
        }
        let below:u64 = p[n - 2] >> 63
        if (top == 0 && below == 0) || (top == kv_bi_ones() && below == 1) {
            n -= 1
        } else {
            break
        }
    }
    while l.count as i64 > n { l.pop() }
    return l
}

// l without its top zero limbs, an unsigned magnitude's form
let kv_bi_strip(var l:$[u64]):$[u64] {
    while l.count > 0 && l[l.count - 1] == 0 { l.pop() }
    return l
}

// a + b, or a - b where sub, of raw limbs: a's an limbs with sa, all ones or
// 0, repeated past them, and b's bn with sb; one result, made once
let kv_bi_addp(ap:const u64^, an:i64, sa:u64, bp:const u64^, bn:i64, sb:u64, sub:bool):$[u64] {
    let n:i64 = (an > bn ? an : bn) + 1
    var r = Array<u64>(n)
    let rp:u64^ := r.at
    let flip:u64 = sub ? kv_bi_ones() : 0                // a - b is a + ~b + 1
    let eb:u64 = sb ~ flip
    var carry:u64 = sub ? 1 : 0
    let m:i64 = an < bn ? an : bn
    var i:i64 = 0
    while i < m {
        let t:u128 = (ap[i] as u128) + ((bp[i] ~ flip) as u128) + (carry as u128)
        rp[i] = t as u64
        carry = (t >> 64) as u64
        i += 1
    }
    while i < an {
        let t:u128 = (ap[i] as u128) + (eb as u128) + (carry as u128)
        rp[i] = t as u64
        carry = (t >> 64) as u64
        i += 1
    }
    while i < bn {
        let t:u128 = (sa as u128) + ((bp[i] ~ flip) as u128) + (carry as u128)
        rp[i] = t as u64
        carry = (t >> 64) as u64
        i += 1
    }
    rp[n - 1] = sa + eb + carry
    return kv_bi_norm(r)
}

let kv_bi_add(a:const $[u64]^, b:const $[u64]^):$[u64] {
    return kv_bi_addp(a^.at, a^.count as i64, kv_bi_ext(a), b^.at, b^.count as i64, kv_bi_ext(b), false)
}

let kv_bi_sub(a:const $[u64]^, b:const $[u64]^):$[u64] {
    return kv_bi_addp(a^.at, a^.count as i64, kv_bi_ext(a), b^.at, b^.count as i64, kv_bi_ext(b), true)
}

// a + x, or a - x where sub, of an i64 x, with no BigInt made of it
let kv_bi_add_i64(a:const $[u64]^, x:i64, sub:bool):$[u64] {
    var limb:u64 = x as u64
    return kv_bi_addp(a^.at, a^.count as i64, kv_bi_ext(a), &limb, 1, x < 0 ? kv_bi_ones() : 0, sub)
}

// x - a of an i64 x
let kv_bi_i64_sub(x:i64, a:const $[u64]^):$[u64] {
    var limb:u64 = x as u64
    return kv_bi_addp(&limb, 1, x < 0 ? kv_bi_ones() : 0, a^.at, a^.count as i64, kv_bi_ext(a), true)
}

// l without the top limbs that only repeat the sign, in place
let kv_bi_norm_in(l:$[u64]^):() {
    var n:i64 = l^.count as i64
    let p:const u64^ := l^.at
    while n > 1 {
        let top:u64 = p[n - 1]
        let below:u64 = p[n - 2] >> 63
        if (top == 0 && below == 0) || (top == kv_bi_ones() && below == 1) {
            n -= 1
        } else {
            break
        }
    }
    if n == 1 && p[0] == 0 { n = 0 }
    while l^.count as i64 > n { l^.pop() }
}

// r += b, or r -= b where sub, in place (#518): r grown by its sign to
// the limbs the result needs, which it holds after the first steps, so
// that a sum kept in a var is made no more; bp is none of r's limbs
let kv_bi_addto(r:$[u64]^, bp:const u64^, bn:i64, sb:u64, sub:bool):() {
    let an:i64 = r^.count as i64
    let n:i64 = (an > bn ? an : bn) + 1
    let sa:u64 = kv_bi_ext(r)
    while r^.count as i64 < n { r^ += sa }
    let rp:u64^ := r^.at
    let flip:u64 = sub ? kv_bi_ones() : 0
    let eb:u64 = sb ~ flip
    var carry:u64 = sub ? 1 : 0
    var i:i64 = 0
    while i < bn {
        let t:u128 = (rp[i] as u128) + ((bp[i] ~ flip) as u128) + (carry as u128)
        rp[i] = t as u64
        carry = (t >> 64) as u64
        i += 1
    }
    while i < n {
        let t:u128 = (rp[i] as u128) + (eb as u128) + (carry as u128)
        rp[i] = t as u64
        carry = (t >> 64) as u64
        i += 1
    }
    kv_bi_norm_in(r)
}

// r += b and r -= b of a BigInt; of r itself, s += s, a new one
let kv_bi_add_to(r:$[u64]^, b:const $[u64]^, sub:bool):() {
    if b^.count > 0 && r^.at == b^.at {
        r^ = kv_bi_addp(r^.at, r^.count as i64, kv_bi_ext(r), b^.at, b^.count as i64, kv_bi_ext(b), sub)
        return
    }
    kv_bi_addto(r, b^.at, b^.count as i64, kv_bi_ext(b), sub)
}

// r += x and r -= x of an i64
let kv_bi_add_to_i64(r:$[u64]^, x:i64, sub:bool):() {
    var limb:u64 = x as u64
    kv_bi_addto(r, &limb, 1, x < 0 ? kv_bi_ones() : 0, sub)
}

let kv_bi_neg(a:const $[u64]^):$[u64] {
    var zero:u64 = 0
    return kv_bi_addp(&zero, 0, 0, a^.at, a^.count as i64, kv_bi_ext(a), true)
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
    return kv_bi_strip(a^.copy())
}

// the value of the magnitude m with a sign
let kv_bi_signed(var m:$[u64], negative:bool):$[u64] {
    m = kv_bi_strip(m)
    if m.count > 0 && (m[m.count - 1] >> 63) == 1 { m += 0 }   // a sign limb above a full top limb
    if negative && m.count > 0 { m = kv_bi_neg(&m) }
    return kv_bi_norm(m)
}

// the limbs of a non-negative value without its top zero limb: the count of
// its magnitude, read in place
let kv_bi_ucount(a:const $[u64]^):i64 {
    var n:i64 = a^.count as i64
    while n > 0 && a^[n - 1] == 0 { n -= 1 }
    return n
}

// ---------- magnitudes: multiplication and division ----------

// the limbs of the magnitude a from lo up to hi, no top zeros
let kv_bi_slice(a:const $[u64]^, lo:i64, hi:i64):$[u64] {
    let top:i64 = hi < a^.count as i64 ? hi : a^.count as i64
    if lo >= top { return Array<u64>() }
    var r = Array<u64>(top - lo)
    let rp:u64^ := r.at
    let ap:const u64^ := a^.at
    for i in lo..<top { rp[i - lo] = ap[i] }
    return kv_bi_strip(r)
}

// the magnitudes a + b
let kv_bi_uadd(a:const $[u64]^, b:const $[u64]^):$[u64] {
    var r = kv_bi_addp(a^.at, a^.count as i64, 0, b^.at, b^.count as i64, 0, false)
    return kv_bi_strip(r)
}

// the magnitudes a - b, where a is b or more
let kv_bi_usub(a:const $[u64]^, b:const $[u64]^):$[u64] {
    var r = kv_bi_addp(a^.at, a^.count as i64, 0, b^.at, b^.count as i64, 0, true)
    if r.count > 0 && r[r.count - 1] == kv_bi_ones() { r.pop() }   // not reached where a is b or more
    return kv_bi_strip(r)
}

// r += a, shifted up k limbs, in place; r has room
let kv_bi_add_at(r:$[u64]^, a:const $[u64]^, k:i64):() {
    let rp:u64^ := &r^.at[k]
    let ap:const u64^ := a^.at
    let n:i64 = a^.count as i64
    var carry:u64 = 0
    var i:i64 = 0
    while i < n {
        let t:u128 = (rp[i] as u128) + (ap[i] as u128) + (carry as u128)
        rp[i] = t as u64
        carry = (t >> 64) as u64
        i += 1
    }
    while carry != 0 {
        let t:u64 = rp[i] + carry
        carry = t < carry ? 1 : 0
        rp[i] = t
        i += 1
    }
}

// rp += ap * bp, the schoolbook's, rp zeroed for its an + bn limbs
let kv_bi_mul_into(rp:u64^, ap:const u64^, an:i64, bp:const u64^, bn:i64):() {
    for i in 0..<an {
        let x:u128 = ap[i] as u128
        if x != 0 {
            let rq:u64^ := &rp[i]
            var carry:u64 = 0
            for j in 0..<bn {
                let t:u128 = x * (bp[j] as u128) + (rq[j] as u128) + (carry as u128)
                rq[j] = t as u64
                carry = (t >> 64) as u64
            }
            rq[bn] = carry
        }
    }
}

// rp = ap squared, the schoolbook's, each product of two limbs once and
// doubled, rp zeroed for its 2an limbs
let kv_bi_sqr_into(rp:u64^, ap:const u64^, an:i64):() {
    for i in 0..<(an - 1) {
        let x:u128 = ap[i] as u128
        if x != 0 {
            var carry:u64 = 0
            for j in (i + 1)..<an {
                let t:u128 = x * (ap[j] as u128) + (rp[i + j] as u128) + (carry as u128)
                rp[i + j] = t as u64
                carry = (t >> 64) as u64
            }
            rp[i + an] = carry
        }
    }
    var top:u64 = 0                                      // doubled
    for i in 0..<(2 * an) {
        let x:u64 = rp[i]
        rp[i] = (x << 1) | top
        top = x >> 63
    }
    var carry:u64 = 0                                    // and the squares added
    for i in 0..<an {
        let t:u128 = (ap[i] as u128) * (ap[i] as u128) + (rp[2 * i] as u128) + (carry as u128)
        rp[2 * i] = t as u64
        let u:u128 = (t >> 64) + (rp[2 * i + 1] as u128)
        rp[2 * i + 1] = u as u64
        carry = (u >> 64) as u64
    }
}

let kv_bi_school(a:const $[u64]^, b:const $[u64]^):$[u64] {
    let an:i64 = a^.count as i64
    let bn:i64 = b^.count as i64
    if an == 0 || bn == 0 { return Array<u64>() }
    var r = Array<u64>(an + bn)
    if a == b {
        kv_bi_sqr_into(r.at, a^.at, an)
    } else {
        kv_bi_mul_into(r.at, a^.at, an, b^.at, bn)
    }
    return kv_bi_strip(r)
}

// the magnitudes a * b, by Karatsuba's three halves past 40 limbs each,
// as swift-bignum, else the schoolbook's; a square where a is b, its
// halves squares too
let kv_bi_umul(a:const $[u64]^, b:const $[u64]^):$[u64] {
    if a^.count >= 40 && b^.count >= 40 {
        let k:i64 = ((a^.count > b^.count ? a^.count : b^.count) as i64 + 1) / 2
        if a == b {
            let a0 = kv_bi_slice(a, 0, k)
            let a1 = kv_bi_slice(a, k, a^.count as i64)
            let z0 = kv_bi_umul(&a0, &a0)
            let z2 = kv_bi_umul(&a1, &a1)
            let sa = kv_bi_uadd(&a0, &a1)
            let z1a = kv_bi_umul(&sa, &sa)
            let z1b = kv_bi_usub(&z1a, &z0)
            let z1 = kv_bi_usub(&z1b, &z2)
            var r = Array<u64>(2 * a^.count + 1)
            kv_bi_add_at(&r, &z0, 0)
            kv_bi_add_at(&r, &z1, k)
            kv_bi_add_at(&r, &z2, 2 * k)
            return kv_bi_strip(r)
        }
        if b^.count as i64 > k && a^.count as i64 > k {
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
    }
    return kv_bi_school(a, b)
}

// the magnitude a divided by the limb d, the remainder into rem
let kv_bi_udiv1(a:const $[u64]^, d:u64, rem:u64^):$[u64] {
    var q = Array<u64>(a^.count)
    let qp:u64^ := q.at
    let ap:const u64^ := a^.at
    var r:u128 = 0
    var i:i64 = a^.count as i64 - 1
    while i >= 0 {
        let cur:u128 = (r << 64) | (ap[i] as u128)
        qp[i] = (cur / (d as u128)) as u64
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
    if (y >> 32) == 0 { n += 32; y = y << 32 }
    if (y >> 48) == 0 { n += 16; y = y << 16 }
    if (y >> 56) == 0 { n += 8; y = y << 8 }
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
        r^ = kv_bi_strip(u^.copy())
        return
    }
    let m:i64 = u^.count as i64 - n
    let s:i64 = kv_bi_clz(v^[n - 1])
    var vn = Array<u64>(n)
    var un = Array<u64>(u^.count + 1)
    let vp:u64^ := vn.at
    let up:u64^ := un.at
    let v0:const u64^ := v^.at
    let u0:const u64^ := u^.at
    for i in 0..<n {
        vp[i] = s > 0 && i > 0 ? (v0[i] << s) | (v0[i - 1] >> (64 - s)) : v0[i] << s
    }
    for i in 0..<(u^.count as i64) {
        up[i] = s > 0 && i > 0 ? (u0[i] << s) | (u0[i - 1] >> (64 - s)) : u0[i] << s
    }
    up[u^.count] = s > 0 ? u0[u^.count - 1] >> (64 - s) : 0
    var qs = Array<u64>(m + 1)
    let qp:u64^ := qs.at
    let base:u128 = (1 as u128) << 64
    let vtop:u128 = vp[n - 1] as u128
    let vnext:u128 = vp[n - 2] as u128
    var j:i64 = m
    while j >= 0 {
        let uj:u64^ := &up[j]
        let num:u128 = ((uj[n] as u128) << 64) | (uj[n - 1] as u128)
        var qhat:u128 = num / vtop
        var rhat:u128 = num - qhat * vtop
        while qhat >= base || qhat * vnext > ((rhat << 64) | (uj[n - 2] as u128)) {
            qhat -= 1
            rhat += vtop
            if rhat >= base { break }
        }
        let qd:u64 = qhat as u64
        var carry:u64 = 0                                // uj -= qd * v
        var borrow:u64 = 0
        for i in 0..<n {
            let p:u128 = (qd as u128) * (vp[i] as u128) + (carry as u128)
            carry = (p >> 64) as u64
            let t:u128 = (uj[i] as u128) - ((p as u64) as u128) - (borrow as u128)
            uj[i] = t as u64
            borrow = ((t >> 64) as u64) & 1
        }
        let t:u128 = (uj[n] as u128) - (carry as u128) - (borrow as u128)
        uj[n] = t as u64
        qp[j] = qd
        if ((t >> 64) as u64) != 0 {                     // one too many: v added back
            qp[j] = qd - 1
            var c:u64 = 0
            for i in 0..<n {
                let w:u128 = (uj[i] as u128) + (vp[i] as u128) + (c as u128)
                uj[i] = w as u64
                c = (w >> 64) as u64
            }
            uj[n] = uj[n] + c
        }
        j -= 1
    }
    var rs = Array<u64>(n)
    let rp:u64^ := rs.at
    for i in 0..<n {
        rp[i] = s > 0 ? (up[i] >> s) | (up[i + 1] << (64 - s)) : up[i]
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
    var r = Array<u64>(n)
    let rp:u64^ := r.at
    for i in 0..<n {
        let x:u64 = kv_bi_limb(a, i)
        let y:u64 = kv_bi_limb(b, i)
        rp[i] = op == 0 ? x & y : op == 1 ? x | y : x ~ y
    }
    return kv_bi_norm(r)
}

let kv_bi_not(a:const $[u64]^):$[u64] {
    if a^.count == 0 {
        var r:$[u64] = $[]
        r += kv_bi_ones()
        return r
    }
    var r = Array<u64>(a^.count)
    let rp:u64^ := r.at
    let ap:const u64^ := a^.at
    for i in 0..<(a^.count as i64) { rp[i] = ~ap[i] }
    return kv_bi_norm(r)
}

let kv_bi_shl(a:const $[u64]^, k:i64):$[u64] {
    let w:i64 = k / 64
    let b:i64 = k % 64
    let n:i64 = a^.count as i64
    var r = Array<u64>(w + n + 1)
    let rp:u64^ := r.at
    let ap:const u64^ := a^.at
    var prev:u64 = 0
    for i in 0..<n {
        let x:u64 = ap[i]
        rp[w + i] = b > 0 ? (x << b) | (prev >> (64 - b)) : x
        prev = x
    }
    let ext:u64 = kv_bi_ext(a)
    rp[w + n] = b > 0 ? (ext << b) | (prev >> (64 - b)) : ext
    return kv_bi_norm(r)
}

// a shifted right k bits, the sign kept: a divided by 2 ** k, rounded down
let kv_bi_shr(a:const $[u64]^, k:i64):$[u64] {
    let w:i64 = k / 64
    let b:i64 = k % 64
    let n:i64 = a^.count as i64
    let ext:u64 = kv_bi_ext(a)
    let len:i64 = n > w ? n - w : 0
    var r = Array<u64>(len + 1)
    let rp:u64^ := r.at
    let ap:const u64^ := a^.at
    for i in 0..<len {
        let lo:u64 = ap[w + i]
        let hi:u64 = w + i + 1 < n ? ap[w + i + 1] : ext
        rp[i] = b > 0 ? (lo >> b) | (hi << (64 - b)) : lo
    }
    rp[len] = ext                                        // all of it shifted out: 0, or -1 of a negative one
    return kv_bi_norm(r)
}

// ---------- text ----------

let kv_bi_digits():cstr { "0123456789abcdefghijklmnopqrstuvwxyz" }

let kv_bi_bad_base(base:i64):() {
    fprintf(stderr, "kelvin: a BigInt's text has a base from 2 to 36, and this is %lld\n", base)
    kv_exit_failure()
}

// the largest power of base in a limb, and its digits, into width
let kv_bi_chunk(base:i64, width:i64^):u64 {
    var chunk:u64 = base as u64
    var w:i64 = 1
    while chunk <= kv_bi_ones() / (base as u64) {
        chunk = chunk * (base as u64)
        w += 1
    }
    width^ = w
    return chunk
}

// the digits of the magnitude m into out, by the schoolbook's: divided in
// halves of a limb, so that each step is a u64's division; exactly pad of
// them, zeros before, where pad > 0, else with no leading zeros
let kv_bi_text_small(m:const $[u64]^, base:i64, pad:i64, out:Bytes^):() {
    var chunk:u64 = base as u64                          // the largest power of base below 2 ** 32
    var width:i64 = 1
    while chunk * (base as u64) < ((1 as u64) << 32) {
        chunk = chunk * (base as u64)
        width += 1
    }
    var h = Array<u64>(2 * m^.count)
    let hp:u64^ := h.at
    let mp:const u64^ := m^.at
    for i in 0..<(m^.count as i64) {
        hp[2 * i] = mp[i] & 0xffffffff
        hp[2 * i + 1] = mp[i] >> 32
    }
    var hn:i64 = h.count as i64
    while hn > 0 && hp[hn - 1] == 0 { hn -= 1 }
    var parts:$[u64] = $[]
    while hn > 0 {
        var r:u64 = 0
        var i:i64 = hn - 1
        while i >= 0 {
            let cur:u64 = (r << 32) | hp[i]
            hp[i] = cur / chunk
            r = cur - hp[i] * chunk
            i -= 1
        }
        parts += r
        while hn > 0 && hp[hn - 1] == 0 { hn -= 1 }
    }
    let total:i64 = parts.count as i64 * width
    var skip:i64 = 0
    if pad > 0 {
        for _ in total..<pad { out^ += '0' as u8 }
        skip = total > pad ? total - pad : 0
    }
    let digits := kv_bi_digits()
    var here = Array<u8>(width)
    let ep:u8^ := here.at
    var first = pad == 0
    var i:i64 = parts.count as i64 - 1
    while i >= 0 {
        var v:u64 = parts[i]
        var k:i64 = width - 1
        while k >= 0 {
            ep[k] = digits[v % (base as u64)]
            v = v / (base as u64)
            k -= 1
        }
        var from:i64 = 0
        if first {
            while from < width - 1 && ep[from] == '0' as u8 { from += 1 }
            first = false
        }
        while skip > 0 && from < width {
            from += 1
            skip -= 1
        }
        for d in from..<width { out^ += ep[d] }
        i -= 1
    }
}

// the digits of the magnitude m into out, divided and conquered: by pows[k],
// the chunk to the 2 ** k, into a high half and a low half of width * 2 ** k
// digits; pad as kv_bi_text_small's
let kv_bi_text_dc(m:const $[u64]^, pows:const $[$[u64]]^, k:i64, base:i64, width:i64, pad:i64, out:Bytes^):() {
    if k < 1 || m^.count < 32 {
        kv_bi_text_small(m, base, pad, out)
        return
    }
    if pad == 0 && kv_bi_cmp_mag(m, &pows^[k]) < 0 {
        kv_bi_text_dc(m, pows, k - 1, base, width, 0, out)
        return
    }
    var q:$[u64] = $[]
    var r:$[u64] = $[]
    kv_bi_udivmod(m, &pows^[k], &q, &r)
    let low:i64 = width << k
    kv_bi_text_dc(&q, pows, k - 1, base, width, pad > 0 ? pad - low : 0, out)
    kv_bi_text_dc(&r, pows, k - 1, base, width, low, out)
}

// the text of a in base, its digits lowercase, a '-' before a negative one
let kv_bi_text(a:const $[u64]^, base:i64):String {
    if base < 2 || base > 36 { kv_bi_bad_base(base) }
    if a^.count == 0 { return $"0" }
    var width:i64 = 0
    let chunk:u64 = kv_bi_chunk(base, &width)
    let m = kv_bi_mag(a)
    var pows:$[$[u64]] = $[]                             // the chunk, squared and squared
    var p:$[u64] = $[]
    p += chunk
    pows += &p
    while pows[pows.count - 1].count * 2 <= m.count {
        let last:const $[u64]^ := &pows[pows.count - 1]
        pows += kv_bi_umul(last, last)
    }
    var out = Bytes()
    if kv_bi_negative(a) { out += '-' as u8 }
    kv_bi_text_dc(&m, &pows, pows.count as i64 - 1, base, width, 0, &out)
    return out.string() ?? $""
}

// a's text as a literal, which reads back as a (#509): a sign, the prefix of
// the base, its digits and an n, +0xffn
let kv_bi_prefixed(a:const $[u64]^, base:i64, prefix:cstr):String {
    let m = kv_bi_signed(kv_bi_mag(a), false)           // the value of the magnitude: a full top limb is no sign (#518)
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
    var carry:u64 = a
    let mp:u64^ := m^.at
    for i in 0..<(m^.count as i64) {
        let t:u128 = (mp[i] as u128) * (f as u128) + (carry as u128)
        mp[i] = t as u64
        carry = (t >> 64) as u64
    }
    if carry != 0 { m^ += carry }
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
    var start:i64 = i
    while kv_bi_digit(s[i], base) >= 0 { i += 1 }
    m.reserve((i - start) / 8 + 2)
    var chunk:u64 = 0
    var scale:u64 = 1
    var j:i64 = start
    while j < i {
        chunk = chunk * (base as u64) + (kv_bi_digit(s[j], base) as u64)
        scale = scale * (base as u64)
        if scale > kv_bi_ones() / (base as u64) {
            kv_bi_mul_add(&m, scale, chunk)
            chunk = 0
            scale = 1
        }
        j += 1
    }
    if scale > 1 { kv_bi_mul_add(&m, scale, chunk) }
    return kv_bi_signed(m, negative)
}

// ---------- powers, gcd, square roots ----------

// the magnitude m squared and multiplied: m ** e; the factors of 2 in m
// shifted in at the end, so that a power of 2 is a shift
let kv_bi_upow(m:const $[u64]^, e:u64):$[u64] {
    if m^.count == 0 {                                   // 0 ** 0 is 1, 0 ** e 0
        var z:$[u64] = $[]
        if e == 0 { z += 1 }
        return z
    }
    var r:$[u64] = $[]
    r += 1
    var tz:i64 = 0                                       // m's trailing zero bits
    while ((m^[tz / 64] >> (tz % 64)) & 1) == 0 { tz += 1 }
    let v = kv_bi_signed(m^.copy(), false)               // the value, so that shr keeps it non-negative
    var x = kv_bi_strip(kv_bi_shr(&v, tz))
    var k:u64 = e
    while k > 0 {
        if (k & 1) == 1 { r = kv_bi_umul(&r, &x) }
        k = k >> 1
        if k > 0 { x = kv_bi_umul(&x, &x) }
    }
    let s = kv_bi_signed(r, false)                       // 2 ** (tz * e) shifted in
    let t = kv_bi_shl(&s, tz * (e as i64))
    return kv_bi_strip(t)
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

// a * b of two values, the sign by theirs; non-negative ones read in place
let kv_bi_mul(a:const $[u64]^, b:const $[u64]^):$[u64] {
    if a^.count == 0 || b^.count == 0 { return Array<u64>() }
    if !kv_bi_negative(a) && !kv_bi_negative(b) {
        let p = kv_bi_umul(a, b)
        return kv_bi_signed(p, false)
    }
    let ma = kv_bi_mag(a)
    if a == b { return kv_bi_signed(kv_bi_umul(&ma, &ma), false) }
    let mb = kv_bi_mag(b)
    let p = kv_bi_umul(&ma, &mb)
    return kv_bi_signed(p, kv_bi_negative(a) != kv_bi_negative(b))
}

// a * x of an i64 x: one pass of a non-negative a by a non-negative x, with
// no BigInt made of it
let kv_bi_mul_i64(a:const $[u64]^, x:i64):$[u64] {
    if x < 0 || kv_bi_negative(a) {
        var b:$[u64] = $[]
        b += x as u64                                    // an i64's limb is its value in two's complement
        let c = kv_bi_norm(b)
        return kv_bi_mul(a, &c)
    }
    let n:i64 = a^.count as i64
    if n == 0 || x == 0 { return Array<u64>() }
    var r = Array<u64>(n + 1)
    let rp:u64^ := r.at
    let ap:const u64^ := a^.at
    var carry:u64 = 0
    for i in 0..<n {
        let t:u128 = (ap[i] as u128) * (x as u128) + (carry as u128)
        rp[i] = t as u64
        carry = (t >> 64) as u64
    }
    rp[n] = carry
    return kv_bi_norm(r)
}

// r *= x of an i64, in place where both are non-negative (#518)
let kv_bi_mul_to_i64(r:$[u64]^, x:i64):() {
    if x < 0 || kv_bi_negative(r) {
        r^ = kv_bi_mul_i64(r, x)
        return
    }
    if x == 0 {
        r^.clear()
        return
    }
    let n:i64 = r^.count as i64
    let rp:u64^ := r^.at
    var carry:u64 = 0
    for i in 0..<n {
        let t:u128 = (rp[i] as u128) * (x as u128) + (carry as u128)
        rp[i] = t as u64
        carry = (t >> 64) as u64
    }
    if carry != 0 { r^ += carry }
    if r^.count > 0 && (r^[r^.count - 1] >> 63) == 1 { r^ += 0 }   // still non-negative
    kv_bi_norm_in(r)
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
        if i + 1 < k.count as i64 * 64 {
            let s = kv_bi_mul(&x, &x)
            x = kv_bi_floor_mod(&s, &n)
        }
    }
    if kv_bi_negative(m) && r.count > 0 { r = kv_bi_sub(&r, &n) }
    return r
}

// the greatest common divisor of two u64s, by Euclid's
let kv_bi_gcd1(a:u64, b:u64):u64 {
    var x:u64 = a
    var y:u64 = b
    while y != 0 {
        let t:u64 = x % y
        x = y
        y = t
    }
    return x
}

// the top 62 bits of the magnitude at p, of n limbs, at the place of the
// magnitude of top limbs: 0 above n
let kv_bi_top62(p:const u64^, n:i64, top:i64, sh:i64):i64 {
    let hi:u64 = top < n ? p[top] : 0
    let lo:u64 = top - 1 < n && top >= 1 ? p[top - 1] : 0
    let x:u64 = sh > 0 ? (hi << sh) | (lo >> (64 - sh)) : hi
    return (x >> 2) as i64
}

// the greatest common divisor of a and b, 0 or more, by Lehmer's: the
// steps of Euclid's on their top 62 bits, as long as Knuth's test says
// they are its steps on the whole, then the whole changed by them at once,
// in place; a step of a whole division where none was found
let kv_bi_gcd(a:const $[u64]^, b:const $[u64]^):$[u64] {
    var xs = kv_bi_mag(a)
    var ys = kv_bi_mag(b)
    var xp:u64^ := xs.at
    var yp:u64^ := ys.at
    var xn:i64 = xs.count as i64
    var yn:i64 = ys.count as i64
    if kv_bi_cmp_mag(&xs, &ys) < 0 {
        let tp:u64^ := xp
        xp := yp
        yp := tp
        let tn:i64 = xn
        xn = yn
        yn = tn
    }
    while yn > 1 {
        let sh:i64 = kv_bi_clz(xp[xn - 1])
        var xh:i64 = kv_bi_top62(xp, xn, xn - 1, sh)
        var yh:i64 = kv_bi_top62(yp, yn, xn - 1, sh)
        var aa:i64 = 1                                   // each below 2 ** 62, as xh is
        var bb:i64 = 0
        var cc:i64 = 0
        var dd:i64 = 1
        while true {
            let d1:i64 = yh + cc
            let d2:i64 = yh + dd
            if d1 <= 0 || d2 <= 0 { break }
            let n1:i64 = xh + aa
            let n2:i64 = xh + bb
            if n1 < 0 || n2 < 0 { break }
            var q:i64 = 0                                // 1, 2 and 3, most of them, without a division
            let r1:i64 = n1 - d1
            if r1 < 0 {
                q = 0
            } else if r1 < d1 {
                q = 1
            } else if r1 - d1 < d1 {
                q = 2
            } else if r1 - d1 - d1 < d1 {
                q = 3
            } else {
                q = n1 / d1
            }
            let p:i128 = (q as i128) * (d2 as i128)      // q is n2 / d2's too: Knuth's test, by a product
            if p > (n2 as i128) || (n2 as i128) - p >= (d2 as i128) { break }
            let t1:i64 = (aa as i128 - (q as i128) * (cc as i128)) as i64
            aa = cc
            cc = t1
            let t2:i64 = (bb as i128 - (q as i128) * (dd as i128)) as i64
            bb = dd
            dd = t2
            let t3:i64 = (xh as i128 - (q as i128) * (yh as i128)) as i64
            xh = yh
            yh = t3
        }
        if bb == 0 {                                     // a step of a whole division
            var u = Array<u64>(xn)
            var v = Array<u64>(yn)
            let upp:u64^ := u.at
            let vpp:u64^ := v.at
            for i in 0..<xn { upp[i] = xp[i] }
            for i in 0..<yn { vpp[i] = yp[i] }
            var q:$[u64] = $[]
            var r:$[u64] = $[]
            kv_bi_udivmod(&u, &v, &q, &r)
            for i in 0..<yn { xp[i] = yp[i] }
            xn = yn
            let rp:const u64^ := r.at
            for i in 0..<(r.count as i64) { yp[i] = rp[i] }
            yn = r.count as i64
        } else {                                         // x, y = a x + b y, c x + d y
            // a and b have opposite signs, as c and d do: each a difference
            // of two products of u64s, its carry signed
            // a and c of opposite signs, as Euclid's cofactors alternate
            let pa:bool = aa >= 0
            let ua:u128 = (pa ? aa : 0 - aa) as u128
            let ub:u128 = (pa ? 0 - bb : bb) as u128
            let uc:u128 = (pa ? 0 - cc : cc) as u128
            let ud:u128 = (pa ? dd : 0 - dd) as u128
            // x' = |a| x - |b| y and y' = |d| y - |c| x where a >= 0, else
            // each the other way; past y, whose limbs are 0, x' and y' are
            // 0, so its limbs are not read
            var cx:i128 = 0
            var cy:i128 = 0
            if pa {
                for i in 0..<yn {
                    let xv:u128 = xp[i] as u128
                    let yv:u128 = yp[i] as u128
                    let s:i128 = ((ua * xv) as i128) - ((ub * yv) as i128) + cx
                    let t:i128 = ((ud * yv) as i128) - ((uc * xv) as i128) + cy
                    xp[i] = s as u64
                    yp[i] = t as u64
                    cx = s >> 64
                    cy = t >> 64
                }
            } else {
                for i in 0..<yn {
                    let xv:u128 = xp[i] as u128
                    let yv:u128 = yp[i] as u128
                    let s:i128 = ((ub * yv) as i128) - ((ua * xv) as i128) + cx
                    let t:i128 = ((uc * xv) as i128) - ((ud * yv) as i128) + cy
                    xp[i] = s as u64
                    yp[i] = t as u64
                    cx = s >> 64
                    cy = t >> 64
                }
            }
            xn = yn
            while xn > 0 && xp[xn - 1] == 0 { xn -= 1 }
            while yn > 0 && yp[yn - 1] == 0 { yn -= 1 }
        }
    }
    var g = Array<u64>(xn)
    let gp:u64^ := g.at
    for i in 0..<xn { gp[i] = xp[i] }
    if yn == 1 {
        let yv:u64 = yp[0]
        var r:u128 = 0
        var i:i64 = xn - 1
        while i >= 0 {
            r = ((r << 64) | (xp[i] as u128)) % (yv as u128)
            i -= 1
        }
        var one:$[u64] = $[]
        one += kv_bi_gcd1(yv, r as u64)
        return kv_bi_signed(one, false)
    }
    return kv_bi_signed(g, false)
}

// the bits of the magnitude m
let kv_bi_bitlen(m:const $[u64]^):i64 {
    let n:i64 = kv_bi_ucount(m)
    if n == 0 { return 0 }
    return n * 64 - kv_bi_clz(m^[n - 1])
}

// the floor of the square root of a, Python's math.isqrt: Newton's with
// its precision doubled each step, from the top bits down, then corrected
// by one at most
let kv_bi_isqrt(a:const $[u64]^):$[u64] {
    if kv_bi_negative(a) { kv_array_fail("'.isqrt()' of a negative BigInt has none") }
    if a^.count == 0 { return Array<u64>() }
    let c:i64 = (kv_bi_bitlen(a) - 1) / 2
    var x:$[u64] = $[]
    x += 1
    var d:i64 = 0
    var cb:i64 = 0                                       // c's bits
    while (c >> cb) > 0 { cb += 1 }
    var s:i64 = cb - 1
    while s >= 0 {
        let e:i64 = d
        d = c >> s
        let hi = kv_bi_shl(&x, d - e - 1)
        let lo = kv_bi_shr(a, 2 * c - e - d + 1)
        var q:$[u64] = $[]
        var r:$[u64] = $[]
        kv_bi_divmod(&lo, &x, &q, &r)
        x = kv_bi_add(&hi, &q)
        s -= 1
    }
    let sq = kv_bi_mul(&x, &x)
    if kv_bi_cmp(&sq, a) > 0 { x = kv_bi_add_i64(&x, 1, true) }
    return x
}

// ---------- bits (#531) ----------

let kv_bi_bad_place(n:i64):() {
    fprintf(stderr, "kelvin: a BigInt's bit is at place 0 or more, and this is %lld\n", n)
    kv_exit_failure()
}

// bit n of l, as a bool: past its top the sign, as a two's complement
// number of any width has it
let kv_bi_bit(l:const $[u64]^, n:i64):bool {
    if n < 0 { kv_bi_bad_place(n) }
    return ((kv_bi_limb(l, n / 64) >> (n % 64)) & 1) == 1
}

// bit n of l set to v, in place: past its top l grows by its sign, which
// stays as it was, as l | 1 << n and l & ~(1 << n) leave it
let kv_bi_bit_set(l:$[u64]^, n:i64, v:bool):() {
    if kv_bi_bit(l, n) == v { return }
    let ext:u64 = kv_bi_ext(l)
    while l^.count as i64 < n / 64 + 2 { l^ += ext }
    let p:u64^ := l^.at
    p[n / 64] = p[n / 64] ~ ((1 as u64) << (n % 64))
    kv_bi_norm_in(l)
}

let kv_bi_bit_flip(l:$[u64]^, n:i64):() { kv_bi_bit_set(l, n, !kv_bi_bit(l, n)) }

// b.bits[n] = v, |= v, &= v and ~= v, how 0 to 3
let kv_bi_bit_put(l:$[u64]^, n:i64, v:bool, how:i64):() {
    let was:bool = kv_bi_bit(l, n)
    kv_bi_bit_set(l, n, how == 0 ? v : how == 1 ? (was || v) : how == 2 ? (was && v) : was != v)
}

// the bools of l, place 0 first, in the shortest two's complement form:
// the last one is its sign, so 5 is [true, false, true, false], -6
// [false, true, false, true], 0 [false] and -1 [true]
let kv_bi_bools(l:const $[u64]^):$[bool] {
    let sign:bool = kv_bi_negative(l)
    var c:i64 = l^.count as i64 * 64
    if c == 0 { c = 1 }
    while c > 1 && kv_bi_bit(l, c - 2) == sign { c -= 1 }
    var r = Array<bool>(c)
    let rp:bool^ := r.at
    for i in 0..<c { rp[i] = kv_bi_bit(l, i) }
    return r
}

// the limbs of count bools at at, place 0 first, the last one the sign;
// of no bools, 0
let kv_bi_of_bools(at:const bool^, count:i64):$[u64] {
    if count == 0 { return Array<u64>() }
    let n:i64 = (count + 63) / 64
    var r = Array<u64>(n)
    let rp:u64^ := r.at
    for i in 0..<n * 64 {
        if at[i < count ? i : count - 1] { rp[i / 64] = rp[i / 64] | ((1 as u64) << (i % 64)) }
    }
    return kv_bi_norm(r)
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
// of bools, place 0 first, the last one the sign (#531): BigInt(b.bits) is b
let BigInt(bools:lent $[bool]):BigInt { (BigInt){kv_bi_of_bools(bools.at, bools.count as i64)} }
// b.bits[n] of a BigInt lent, which one an expression gives is too
let kv_bi_bit_of(b:lent BigInt, n:i64):bool { kv_bi_bit(&b.limbs, n) }
// of a [bool] of a fixed count, which BigInt([true, false]) and BigInt(bs) of one are
let kv_bi_from_bools(at:const bool^, count:i64):BigInt { (BigInt){kv_bi_of_bools(at, count)} }

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
    let bits:$[bool] { kv_bi_bools(&self.limbs) }         // its bits, each a bool, the last its sign (#531)
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
    let i64:i64 {                                        // the nearest i64, its limit past its range (#513)
        if self.limbs.count <= 1 { return kv_bi_limb(&self.limbs, 0) as i64 }
        return kv_bi_negative(&self.limbs) ? 0 - 9223372036854775807 - 1 : 9223372036854775807
    }
    let u64:u64 {                                        // the nearest u64: 0 of a negative one (#513)
        if kv_bi_negative(&self.limbs) { return 0 }
        if self.limbs.count <= 1 || (self.limbs.count == 2 && self.limbs[1] == 0) { return kv_bi_limb(&self.limbs, 0) }
        return kv_bi_ones()
    }
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
    // x += y, x -= y and x *= n in place, the limbs x holds reused (#518)
    static let +=(a:Self^, b:Self) { kv_bi_add_to(&a^.limbs, &b.limbs, false) }
    static let +=(a:Self^, b:i64) { kv_bi_add_to_i64(&a^.limbs, b, false) }
    static let -=(a:Self^, b:Self) { kv_bi_add_to(&a^.limbs, &b.limbs, true) }
    static let -=(a:Self^, b:i64) { kv_bi_add_to_i64(&a^.limbs, b, true) }
    static let *=(a:Self^, b:i64) { kv_bi_mul_to_i64(&a^.limbs, b) }
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
    static let +(a:Self, b:i64):Self { (Self){kv_bi_add_i64(&a.limbs, b, false)} }   // no BigInt made of b (#518)
    static let +(a:i64, b:Self):Self { (Self){kv_bi_add_i64(&b.limbs, a, false)} }
    static let -(a:Self, b:i64):Self { (Self){kv_bi_add_i64(&a.limbs, b, true)} }
    static let -(a:i64, b:Self):Self { (Self){kv_bi_i64_sub(a, &b.limbs)} }
    static let *(a:Self, b:i64):Self { (Self){kv_bi_mul_i64(&a.limbs, b)} }
    static let *(a:i64, b:Self):Self { (Self){kv_bi_mul_i64(&b.limbs, a)} }
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
