// a ; may be left out at the end of a line, and a function whose body is
// one expression returns it (#35)

struct point {
    x:int32
    y:int32
}
struct node { value:int64; next:node^ }

var total:int64 = 0

let square(x:int64):int64 { x * x }
let point.dist2():int64 {
    .x * .x + .y * .y
}
let proto(x:int64):int64
let proto(x:int64):int64 { x + 1 }
let apply(x:int64, f:(int64):int64):int64 { f(x) }
let each(n:int64, f:(int64)) {
    for i in 0..<n {
        f(i)
    }
}
let nothing() {
    return
}

let main():int32 {
    let price = 5
    let count = 3
    let t:int64 = price
        * count
    let u:int64 = price -
        count
    var p:point = {3, 4}
    println(t, " ", u, " ", square(4), " ", p.dist2(), " ", proto(1))
    var xs:[int32](3) = [3, 1, 2]
    var q:any^ := &xs[0]
    (q as int32^)^ = 9
    println(xs[0])
    each(3) { total += $0 }
    each(2) {
        total += 10
        total += $0
    }
    println(total, " ", apply(2) { $0 * 7 })
    var n = 0
    while n < 3 {
        n += 1
        if n == 2 {
            continue
        }
    }
    do {
        n -= 1
    } while n > 0
    let len:int64 = p
        .dist2()
    println(n, " ", len)
    var a = 1; var b = 2
    a += b; b += a
    println(a, " ", b)
    nothing()
    let w := { (x:int64):int64 in
        let y:int64 = x * 2
        return y + 1
    }
    println(w(3))
    return 0
}
// out: 15 2 16 25 2
// out: 9
// out: 24 14
// out: 0 25
// out: 3 5
// out: 7
