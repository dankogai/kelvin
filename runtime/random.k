// runtime/random.k - T.random() of the number types and of bool (#547),
// written in Kelvin (#289): kelvinc --runtime builds it into libkelvin,
// each kv_ function by the name kelvin_prelude.h declares. Its bits are
// the system's, kv_random_fill of runtime/prelude.c, which has no seed:
// no run repeats another. The C kelvinc and kc write calls these.

// 64 bits, each as likely as not
let kv_random_u64():u64 {
    var x:u64 = 0
    kv_random_fill(&x, 8)
    return x
}

// 128 bits
let kv_random_u128():u128 {
    let hi:u128 = u128(kv_random_u64())
    return (hi << 64) | u128(kv_random_u64())
}

// a number from 0 up to n, without it, n above 0, each as likely: one
// below what 2^64 leaves over n is drawn again, so that none is likelier
let kv_random_below(n:u64):u64 {
    let over:u64 = (0:u64 - n) % n
    var x:u64 = kv_random_u64()
    while x < over { x = kv_random_u64() }
    return x % n
}

// T.random(r) of a Range<T>: one of its values, each as likely; lo and hi
// are r's bounds as 64 bits, a signed one's sign carried, and kind r's, 0
// of lo..<hi, 1 of lo...hi, 2 of lo..., whose hi is T's largest. An empty
// range has no value to give, and ends the program, as Swift's does
let kv_random_span(lo:u64, hi:u64, kind:int32, is_signed:bool):u64 {
    var empty = kind == 0 ? lo >= hi : lo > hi
    if is_signed {
        let a:i64 = lo as i64
        let b:i64 = hi as i64
        empty = kind == 0 ? a >= b : a > b
    }
    if empty { kv_array_fail("'T.random(r)' takes a range with a value in it, and this one is empty") }
    let last:u64 = kind == 0 ? hi - 1 : hi
    let span:u64 = last - lo
    if span == 0xFFFFFFFFFFFFFFFF { return kv_random_u64() }   // every value of 64 bits
    return lo + kv_random_below(span + 1)
}

// f64.random(): from 0.0 up to 1.0, without it, by 53 bits, each of its
// 2^53 numbers as likely
let kv_random_f64():f64 {
    return f64(kv_random_u64() >> 11) * 0x1p-53
}

// f32.random(): the same by 24 bits
let kv_random_f32():f32 {
    return f32(kv_random_u64() >> 40) * (0x1p-24 as f32)
}

// f64.random(lim) and f64.random(start, lim): from start up to lim,
// without it. A start not below its limit, a NaN, or bounds too far apart
// to tell their distance, has no such number, and ends the program
let kv_random_f64_in(start:f64, lim:f64):f64 {
    let wide:f64 = lim - start
    if !(start < lim) || wide - wide != 0.0 {
        kv_array_fail("'T.random(start, lim)' takes a start below its limit, both finite, and this has no number between them")
    }
    var x:f64 = start + wide * kv_random_f64()
    while x >= lim { x = start + wide * kv_random_f64() }   // rounded up to the limit: drawn again
    return x
}

let kv_random_f32_in(start:f32, lim:f32):f32 {
    let wide:f32 = lim - start
    if !(start < lim) || wide - wide != 0.0 {
        kv_array_fail("'T.random(start, lim)' takes a start below its limit, both finite, and this has no number between them")
    }
    var x:f32 = start + wide * kv_random_f32()
    while x >= lim { x = start + wide * kv_random_f32() }
    return x
}
