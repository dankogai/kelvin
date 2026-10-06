// template literals (#39, #44): each kind of value at its longest text, a
// ?: between texts, byte arrays, and a storage of each call of its own
#import <string.h> as C
enum color { RED, GREEN }
struct wide { a: i128; b: i128; c: i128; d: i128; e: i128; f: i128; g: i128 }
struct box { four: [u8](4); more: [u8](4) }
let down(n:i64) {
    let t:cstr := `n=${n}`
    if n > 0 {
        down(n - 1)
    }
    print(t, " ")
}
let main():i32 {
    let a:i16 = -32768
    let b:u16 = 65535
    let c:u32 = 4294967295
    let d:u128 = u128("340282366920938463463374607431768211455")
    let h:i128 = i128("-170141183460469231731687303715884105728")
    let e:color = GREEN
    let no = false
    println(`${a} ${b} ${c} ${d} ${e} ${h * 1} ${!no} ${sizeof(h)} ${h.size} ${5000000000} ${0x1p3}`)
    println(strlen(`${h.dec}`), " ", strlen(`${h.hex}`), " ", strlen(`${h.oct}`), " ", strlen(`${h.bin}`))
    let n:i64 = 5
    println(`${n > 3 ? "longer text" : "no"} ${n < 3 ? "no" : "longer text"}`)
    var bx:box
    memset(&bx, 'x', sizeof(bx))
    bx.four[0] = 'a'
    bx.four[1] = 0
    var xs:[i32](3) = [1, 2, 3]
    println(`[${bx.four}] ${strcmp(`${xs}`, `${&xs[0]}`) == 0}`)
    let w:wide = {h, h, h, h, h, h, h}
    var text:[u8](400)
    memset(&text[0], 'z', 399)
    text[399] = 0
    let s:cstr := &text[0]
    println(strlen(`${w}`), " ", strlen(`${s.cstr}`))
    down(2)
    println()
    return 0
}
// out: -32768 65535 4294967295 340282366920938463463374607431768211455 1 -170141183460469231731687303715884105728 true 16 16 5000000000 8.0
// out: 40 35 46 131
// out: longer text longer text
// out: [a] true
// out: 315 256
// out: n=0 n=1 n=2 
