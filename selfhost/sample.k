// sample.k - a program of the subset kc reads, beside kc itself: the
// bootstrap builds it with kelvinc and with kc's last stage, and their
// output must be the same. It uses libc as C does (#207).
#import <stdlib.h> as C
#import <string.h> as C

struct point {
    x: int64
    y: int64
}

enum shade { light, middle = 5, dark }

// a switch on an enum names every enumerator (#210)
let shade_name(s:shade):cstr {
    switch s {
    case light: return "light"
    case middle, dark:
        return "not light"
    }
    return "?"
}

extend point {                                        // methods (#213)
    let sum():int64 { return .x + .y }
    let scaled(k:int64):point { return {.x * k, self.y * k} }
    static let of(x:int64, y:int64):Self { return {x, y} }
}
let point.dot(o:point):int64 { return .x * o.x + .y * o.y }

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
    var words:String = $""
    for k in 0..<4 {
        switch k {                                    // a switch on a number has default:
        case 0: words += "zero "
        case 1, 2:
            words += "small "
            if k == 2 { break }
            words += "one "
        default: words += "more"
        }
    }
    let sh:shade = dark
    println(words, " ", shade_name(light), " ", shade_name(sh), " ", sh as int64)
    var counts:Dictionary<String, int64> = ${:}       // (#211)
    var w:String = $"kelvin"
    counts[w] = 1
    counts["c"] = 2
    counts[w] += 10
    var tags:Dictionary<int64, String> = ${:}
    tags[3] = $"three"
    tags[3] = $"drei"
    println(counts[w], " ", counts.get("none", 0 - 1), " ", counts.has("c"), " ", counts.count, " ", tags[3], " ", tags.has(4))
    var label:String = String(0 - 42)                 // a number's text (#212)
    label += String(7)
    label += " "
    label += String(3 as uint8)
    label += String(true)
    println(label, " ", label.count)
    var p:point = point.of(1, 2)
    let q:point^ := &p
    let big:point = p.scaled(3)
    println(p.sum(), " ", big.x, " ", q^.sum(), " ", points[0].dot(p), " ", point.of(3, 4).sum())
    var count = 0                                     // inferred (#214)
    let minus = -3
    let letter = 'k'
    let yes = true
    let less = count < minus
    var greeting = $"hi"
    let raw := "raw"
    let first = points[0]
    let total2 = total(&points)
    let cast = 300 as uint8
    count += 2
    greeting += "!"
    println(count, " ", minus, " ", letter, " ", yes, " ", less, " ", greeting)
    println(raw, " ", first.y, " ", total2, " ", cast)
    return 0
}
