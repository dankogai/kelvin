// a ; may be left out at the end of a line, and a function whose body is
// one expression returns it (#35)

struct point {
    x:i32
    y:i32
}
struct node { value:i64; next:node^ }

var total:i64 = 0

let square(x:i64):i64 { x * x }
let point.dist2():i64 {
    self.x * self.x + self.y * self.y
}
let proto(x:i64):i64
let proto(x:i64):i64 { x + 1 }
let apply(x:i64, f:(i64):i64):i64 { f(x) }
let each(n:i64, f:(i64)) {
    for i in 0..<n {
        f(i)
    }
}
let nothing() {
    return
}

let main():i32 {
    let price = 5
    let count = 3
    let t:i64 = price
        * count
    let u:i64 = price -
        count
    var p:point = {3, 4}
    println(t, " ", u, " ", square(4), " ", p.dist2(), " ", proto(1))
    var xs:i32[3] = {3, 1, 2}
    var q:any^ := &xs[0]
    (q as i32^)^ = 9
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
    let len:i64 = p
        .dist2()
    println(n, " ", len)
    var a = 1; var b = 2
    a += b; b += a
    println(a, " ", b)
    nothing()
    let w := { (x:i64):i64 in
        let y:i64 = x * 2
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
