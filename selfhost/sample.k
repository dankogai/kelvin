// sample.k - a program of the subset kc reads, beside kc itself: the
// bootstrap builds it with kelvinc and with kc's last stage, and their
// output must be the same. It uses libc as C does (#207).
#import <stdlib.h> as C
#import <string.h> as C

struct point {
    x: int64
    y: int64
}

var points:$[point]
let limit:int64 = 10

let add(x:int64, y:int64) {
    let p:point = {x, y}
    points += p
}

let total(ps:$[point]^):int64 {
    var sum:int64 = 0
    for p in ps^ {
        sum += p.x * p.y
    }
    return sum
}

let reversed(s:String^):String {
    var cs:$[uint32] = $[]
    for c in s^ {
        cs += c.utf32
    }
    var r:String = $""
    var i:int64 = cs.count as int64 - 1
    while i >= 0 {
        r += cs[i].uchr
        i -= 1
    }
    return r
}

let fib(n:int64):int64 {
    if n < 2 { return n }
    return fib(n - 1) + fib(n - 2)
}

let main(argc:int32, argv:[cstr]):int32 {
    for i in 0..<limit {
        if i % 3 == 0 {
            add(i, i + 1)
        } else if i % 3 == 1 {
            continue
        } else {
            add(0 - i, 2)
        }
    }
    println(points.count, " points, ", total(&points))
    var s:String = $"λx.Kelvin"
    var r:String = reversed(&s)
    println(r, " ", r.count, " ", r == $"nivleK.xλ", " ", s != r)
    var fibs:$[int64] = $[]
    var n:int64 = 0
    while true {
        if n > 15 { break }
        fibs += fib(n)
        n += 1
    }
    println(fibs.pop(), " ", fibs.count, " ", points[1].y, " ", 'A' as uint8)
    let len:size_t = strlen("kelvin")               // a C typedef, a C function
    let home:cstr := getenv("NO_SUCH_VARIABLE_OF_KC")
    println(len as int64, " ", abs(0 - 7) as int64, " ", home == nullptr)
    return 0
}
