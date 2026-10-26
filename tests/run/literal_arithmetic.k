// arithmetic of literals alone infers its type (#385): an f64 where any is
// one, else an i64, reckoned in 64 bits; arithmetic of variables still
// needs a written type (#47)
let hour = 60 * 60
let big = 65536 * 65536
let main():int32 {
    let ratio = 1.0/0.0
    let half = 1 / 2.0
    let neg = -2.5 * 4
    let paren = (7 + 3) % 4
    let mask = 255 & 15 | 64
    println(ratio, " ", hour, " ", big, " ", half, " ", neg, " ", paren, " ", mask, " ", big / hour)
    return 0
}
// out: inf 3600 4294967296 0.5 -10.0 2 79 1193046
