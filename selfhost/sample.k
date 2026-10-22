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

enum item { none; num: int64; text: String }          // an enum with values (#215)

let describe(v:item^):int64 {
    switch v^ {
    case none: return 0
    case num(n): return n
    case text(s): return s.count as int64
    }
    return -1
}

// Optional and Result (#217)
let find(xs:$[int64]^, v:int64):int64? {
    for i in 0..<xs^.count as int64 {
        if xs^[i] == v { return i }                   // a T where a T? goes: some(i)
    }
    return none
}

let parse_digit(c:uint8):Result<int64, String> {
    if c < '0' || c > '9' {
        var why = $"not a digit: "
        why += String(c as int64)
        return err(why)
    }
    return ok(c as int64 - 48)
}

let named(n:int64):String? {
    if n == 1 { return $"one" }                   // some("one")
    return none
}

struct pet {                                          // a struct that owns, freed (#225)
    name: String
    tricks: $[String]
    age: int64?
}

let adopt(n:cstr):pet {
    var p:pet = {String(n), $[], none}
    p.tricks += $"sit"
    return p
}

let shout(s:String):String {                          // an owner taken by value, which it frees (#226)
    var t = s.copy()
    t += "!"
    return t
}

let either(c:bool, s:String):String {                // c ? a : b (#232): return moves either out
    return c ? s : shout($"other")
}

let half(n:int64):int64? { return n % 2 == 0 ? n / 2 : none }

let twice(n:int64):int64 { return n * 2 }               // overloads, twice__i64 and the rest (#234)
let twice(s:String):String {
    var t = s.copy()
    t += &s
    return t
}
let twice(p:point):point { return {p.x * 2, p.y * 2} }
let kind(n:int32):cstr { return "int32" }
let kind(b:bool):cstr { return "bool" }
let kind(o:int64?):cstr { return "int64?" }

let sum_of(xs:$[int64]):int64 {
    var t:int64 = 0
    for x in xs { t += x }
    return t
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
    println(counts[w]!, " ", counts.get("none", 0 - 1), " ", counts.has("c"), " ", counts.count, " ", tags[3]!, " ", tags.has(4))
    let seen = counts["c"]                            // d[k] read whole is an Optional (#219)
    println(seen ?? 0, " ", counts["none"] ?? 0 - 1, " ", seen.is(some))
    if let some(t) = tags[3] {
        println(t, " ", t.count)
    }
    if let some(t) = tags[4] { println(t) } else { println("no 4") }
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
    var a = item.num(5)
    var b = item.text($"hello")
    var c = item.none
    let isnum = a.is(num)
    let k = a.num
    b.text = $"hi"
    c.num = 3
    var items:$[item] = $[]
    items += item.text($"in an Array")
    println(describe(&a), " ", describe(&b), " ", describe(&c), " ", isnum, " ", k, " ", b.text, " ", items[0].text)
    var hay:$[int64] = $[]
    hay += 4
    hay += 8
    hay += 15
    let at = find(&hay, 15)
    let missing = find(&hay, 16)
    var maybe:int64? = none
    maybe = 7                                         // some(7)
    println(at ?? 0 - 1, " ", missing ?? 0 - 1, " ", at.is(some), " ", missing.is(none), " ", maybe.some)
    var good = parse_digit('7')
    var bad = parse_digit('x')
    if let ok(v) = good {
        println("ok ", v)
    }
    if let err(why) = bad {
        println("err ", why)
    } else {
        println("no error")
    }
    switch good {
    case ok(v): println("switched ok ", v)
    case err(e): println("switched err ", e)
    }
    if let some(word) = named(1) {
        println(word, " ", named(2).is(none))
    }
    var rex = adopt("rex")
    var pets:$[pet] = $[]
    pets += adopt("tom")
    rex.tricks += $"roll"
    rex = adopt("max")                                // the old rex freed
    rex.age = 4
    println(rex.name, " ", rex.tricks.count, " ", rex.age ?? 0, " ", pets[0].name, " ", pets[0].age.is(none))
    var hi = $"hi"
    var loud = shout(hi)                              // hi moves in
    var nums = fibs.copy()
    println(loud, " ", shout($"hey"), " ", sum_of(nums), " ", sum_of(fibs.copy()), " ", fibs.count)
    var letters = 0                                   // temporaries, held while read (#227)
    for c in shout($"abc") { letters += 1 }
    shout($"dropped")
    println(String(42), " ", shout($"x").count, " ", adopt("ace").name, " ", adopt("bo").tricks[0], " ", letters, " ", String(7) == $"7")
    let twofold:int64?? = 4                           // printed as kelvinc prints them (#229)
    let tiny:uint8? = 'k'
    println(at, " ", missing, " ", named(1), " ", good, " ", bad)
    println(a, " ", c, " ", p, " ", twofold, " ", tiny)
    var none_yet:$[int64] = $[]
    println(fibs, " ", none_yet, " ", points, " ", hay)    // Arrays (#230)
    let odd = fibs.count % 2 == 1
    var parity:cstr := "unknown"                      // a reference takes :=, a value = (#233)
    parity := odd ? "odd" : "even"
    let size:int64 = odd ? fibs.count as int64 : 0 - 1
    var picked = either(odd, $"mine")
    println(parity, " ", size, " ", size > 10 ? size > 20 ? "huge" : "big" : "small", " ", half(6), " ", half(7), " ", picked, " ", odd ? picked : loud)
    println(twice(21), " ", twice($"ab"), " ", twice(p).y, " ", kind(3 as int32), " ", kind(true), " ", kind(none))
    var spot:point? = none                            // x?.m, x?.f(), x?[i] chain (#221)
    let unset = spot?.x
    spot = p
    var maybe_hay:$[int64]? = none
    maybe_hay = hay                                   // moves in
    println(named(1)?.count ?? 0, " ", unset ?? 0 - 1, " ", spot?.sum() ?? 0, " ", maybe_hay?[2] ?? 0, " ", tags[3]?.count ?? 0)
    let ratio = 1.5                                   // f64, every digit printed; nan and inf (#262)
    var floats:$[float64] = $[]
    floats += ratio
    floats += 0.1
    floats += -inf
    println(ratio * 2.0, " ", 7 as float64 / 2.0, " ", 2.5e-8, " ", nan, " ", Infinity, " ", floats, " ", 3.9 as int64, " ", ratio < inf)
    let tenth:float32 = 0.1                           // float32, every digit it holds (#263)
    var singles:$[float32] = $[]
    singles += tenth
    singles += -inf as float32
    println(tenth, " ", tenth as float64, " ", tenth * 3.0, " ", 16777217 as float32, " ", singles)
    println(0.1:float32 == tenth, " ", 7:float64 / 2.0, " ", 'z':uint8, " ", 300:uint8, " ", odd ? 1:int64 : 0)   // x:T (#264)
    println(p:point, " ", twice(p:point).y, " ", odd ? p.x : 0, " ", odd ? (p:point).x : 0)   // a struct's name too (#265)
    let primes = $[2, 3, 5, 7]                        // Array literals (#266)
    var labels:$[String] = $["one", $"two"]
    let grid = $[$[1, 2], $[3]]
    println(primes, " ", labels, " ", grid, " ", $[1.5, nan], " ", sum_of($[1, 2, 3]), " ", $[4, 5][1])
    let stock = ${"apple": 3, "pear": 5}              // Dictionary literals (#267)
    let numbers:Dictionary<int64, String> = ${1: "one", 2: $"two"}
    let deep = ${"a": ${"b": 1}}
    println(stock["pear"], " ", stock.count, " ", numbers[2], " ", deep["a"]!["b"], " ", ${"k": 1.5}["k"])
    println(stock, " ", numbers, " ", deep, " ", ${"e": $[1], "f": $[]}, " ", $[stock.copy()])   // Dictionaries whole (#268)
    var fruit = 0                                     // for k, v in d, for k in d (#269)
    for name, count in stock {
        print(name, "=", count, " ")
        fruit += count
    }
    for n in numbers { print(n, " ") }
    println(fruit)
    var basket = stock.copy()                         // d.remove(k) (#270)
    println(basket.remove("apple"), " ", basket.remove("kiwi"), " ", basket, " ", basket.has($"pear"))
    return 0
}
