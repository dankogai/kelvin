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

enum shrub { leaf: int64; twigs: $[shrub] }           // an enum holding an Array of itself (#346)
struct tray { label: cstr; slots: [int64](3) }        // a fixed array as a member (#356)
struct crew { ship: cstr; names: [String](2) }         // of owners, freed and copied with it (#364)

let hail(ns:[String], n:int64) {                       // a parameter's array of owners, its caller's (#365)
    for i in 0..<n { ns[i] += "!" }
}

let rows_sum(m:[[int64](2)], rows:int64):int64 {     // a parameter of fixed arrays, its rows' count written (#370)
    var t = 0
    for i in 0..<rows { t += m[i][0] + m[i][1] }
    return t
}

let letters_in(ns:[const String], n:int64):int64 {
    var t = 0
    for i in 0..<n { t += ns[i].count as int64 }
    return t
}

let total_of(xs:[const int64], n:int64):int64 {        // fixed arrays as parameters (#357)
    var t = 0
    for i in 0..<n { t += xs[i] }
    return t
}

let double_all(xs:[int64], n:int64) {
    for i in 0..<n { xs[i] *= 2 }
}

let weekdays:[cstr] = ["mon", "tue", "wed"]            // fixed arrays as globals (#359)
var hits:[int64](3)
enum hull { round; sides: [int64](3) }                 // a fixed array as an enum's case value (#360, #361)

let first_of(a:[int64](4)^):int64 { a^[0] }            // a fixed array behind a pointer (#362)

let add_up(a:[int64]^, n:int64):int64 {                // and of no count, any count's (#363)
    var s = 0
    for i in 0..<n { s += a^[i] }
    return s
}
enum doc { word: String; fields: Dictionary<String, doc> }   // and a Dictionary of itself (#347)

let leaves(s:const shrub^):int64 {
    switch s^ {
    case leaf(n): return n
    case twigs(ts):
        var sum = 0
        for x in ts { sum += leaves(&x) }
        return sum
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

let peek(p:const int64^):int64 { return p^ }          // a const borrow, which &x of a let is (#272)
let has_even(s:const Set<int64>^):bool {              // a const Set<T>^ (#274)
    for x in s^ { if x % 2 == 0 { return true } }
    return false
}

let largest(xs:const $[int64]^):int64 {               // of an owner too, as kelvinc since #273
    var m:int64 = 0
    for x in xs^ { if x > m { m = x } }
    return m
}

let countdown(var n:int64):int64 {                     // a var parameter may change; a let one may not (#271)
    var steps = 0
    while n > 0 {
        n -= 1
        steps += 1
    }
    return steps
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

let doubled(x:int64):int64 { x * 2 }                // a body's value, returned (#286)
let shouted(s:const String^):String { s^ + "!" }
let louder(s:String):String { s + "!" }              // a call on a thread of its own takes an owner (#313)
let started(n:int64):Task<int64> { async fib(n) }

struct tally_box { n: int64 }                        // a var method, self the caller's var (#320)
var tally_box.bump(by:int64):int64 {
    .n += by
    return .n
}
extend tally_box {
    var reset() { self.n = 0 }
}
struct countdown { n: int64 }                        // an iterator, its var next():T? (#320)
var countdown.next():int64? {
    if .n == 0 { return none }
    .n -= 1
    return .n + 1
}
let count_from(n:int64):countdown { return {n} }
struct span { lo: int64; hi: int64 }                 // a Sequence, its let makeIterator() (#322)
struct span_walk { at: int64; hi: int64 }
var span_walk.next():int64? {
    if .at >= .hi { return none }
    .at += 1
    return .at - 1
}
let span.makeIterator():span_walk { return {.lo, .hi} }
let is_odd(n:int64):bool { n % 2 == 1 }                // a named function a lazy filter takes (#324)
let but_first(_:int64, _:String, n:int64):int64 { n }  // unnamed parameters, `_` (#388)
struct parcel {                                       // types defined inside a struct (#389): bare there, a path outside
    enum wrap { plain; ribbon: int64 }
    struct dims { w: int64; h: int64 }
    w: wrap
    d: dims
}
let parcel.dims.area():int64 { .w * .h }
let parcel.cost():int64 { .d.area() + (.w.is(plain) ? 0 : 5) }
extend parcel.wrap {
    let ribbons():int64 {
        switch self {
        case plain: return 0
        case ribbon: return self.ribbon
        }
    }
}
let twin(k:cstr, v:int64):Dictionary<String, int64> {    // a function flatMapWithKey takes (#332)
    var r:Dictionary<String, int64> = ${:}
    r[String(k)] = v
    r[String(k) + "2"] = v * 2
    return r
}
let fib_upto(limit:int64):Iterator<int64> {             // an Iterator, a state and a function (#326)
    return Iterator($[0, 1, limit]) {                  // what it needs, in its state: it encloses nothing
        let r = $0[0]
        if r > $0[2] { return none }
        let next:int64 = $0[0] + $0[1]
        $0[0] = $0[1]
        $0[1] = next
        return r
    }
}
struct numbered { i: int64; last: int64 }
extend numbered {
    var next():String? {
        .i += 1
        if .i > .last { return none }
        var s = $"w"
        s += String(.i)
        return s
    }
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
    println(countdown(5), " ", countdown(0))
    let fixed = 7
    var loose = 8
    println(peek(&fixed), " ", peek(&loose), " ", largest(&primes), " ", largest(&fibs))
    var digit_set = ${3, 1, 4, 1, 5}                     // Sets (#274)
    digit_set += 9
    let fresh = digit_set.insert(2)
    let odd_only:Set<int64> = {1, 3}
    var name_set:Set<String> = ${}
    name_set += "kelvin"
    println(digit_set, " ", digit_set.count, " ", digit_set.has(4), " ", digit_set.remove(1), " ", fresh, " ", name_set, " ", has_even(&digit_set), " ", has_even(&odd_only))
    println(digit_set.union(&odd_only), " ", digit_set.intersection(&odd_only), " ", digit_set.difference(&odd_only), " ", odd_only.union(&digit_set).count)   // (#275)
    var mixed = digit_set | odd_only                  // | & ~ of Sets and of numbers (#276)
    mixed &= digit_set
    mixed ~= odd_only
    println(digit_set & odd_only, " ", digit_set ~ odd_only, " ", mixed, " ", 12 | 10, " ", 12 & 10, " ", 12 ~ 10, " ", 1 | 2 & 3)
    var listed = digit_set.elements                   // an Array of copies, in the order added (#278)
    listed += 7
    println(listed, " ", name_set.elements, " ", (digit_set | odd_only).elements.count, " ", digit_set.count)
    let joined = greeting + " and " + greeting      // + of Strings, a new String (#284)
    println(joined, " ", "<" + joined + ">", " ", (greeting + greeting).count, " ", joined.count)
    var stock_names = stock.keys                      // Arrays of copies, in the order added (#285)
    stock_names += $"plum"
    println(stock_names, " ", stock.values, " ", numbers.keys, " ", numbers.values, " ", deep.keys, " ", deep.values, " ", stock.keys.count)
    println(doubled(21), " ", shouted(&greeting))
    let same_stock = ${"pear": 5, "apple": 3}            // == of Dictionaries and Arrays (#288)
    println(stock == same_stock, " ", stock != ${"apple": 3}, " ", stock.keys == $[$"apple", $"pear"], " ", listed == digit_set.elements)
    let escaped_text = $"\u{48}i\u00e9\U0001F600\u{7f}"   // \u escapes, UTF-8 bytes in C (#293)
    println(escaped_text.count, " ", escaped_text == $"Hié😀" + (0x7f as uint32).uchr)
    let nul_text = $"a\u{0}bé\\"                     // escape and unescape (#300), a NUL too (#299)
    println(nul_text.escape(), " ", nul_text.escape().unescape() == nul_text, " ", nul_text.count)
    let fib_task = async fib(20)                     // async f(x) and await (#313)
    var word = String("async")
    let loud_task = async louder(word)
    var tasks:$[Task<int64>] = $[]
    for i in 0..<3 { tasks += async doubled(i) }
    var doubled_sum:int64 = 0
    for i in 0..<tasks.count as int64 { doubled_sum += await tasks[i] }
    println(await fib_task, " ", await loud_task, " ", doubled_sum, " ", await started(10), " ", await async doubled(4))
    var tally:Dictionary<String, int64> = ${:}         // a key an expression gives, held (#314)
    tally[String("async") + "s"] = 1
    tally[louder(String("hey"))] = 2
    tally[$"asyncs"] += 10
    println(tally, " ", tally[louder(String("hey"))]!, " ", tally[$"async" + "s"] ?? 0)
    var box:tally_box = {1}                           // var methods and iterators (#320)
    let bumped = box.bump(2)
    box.reset()
    var down:countdown = {4}
    var walked:int64 = 0
    for x in down {
        if x == 2 { break }
        walked += x
    }
    var counted:int64 = 0
    for x in count_from(3) { counted += x }
    var named = $""
    var three:numbered = {0, 3}
    for w in three { named += &w }
    println(bumped, " ", box.n, " ", walked, " ", down.n, " ", counted, " ", named)
    let span3:span = {1, 4}                           // a Sequence, walked afresh each time (#322)
    var spanned:int64 = 0
    for x in span3 { spanned += x }
    for x in span3 { spanned += x * 10 }
    println(spanned, " ", span3.lo, " ", span3.hi)
    let span6:span = {1, 7}                           // lazy map and filter, and anonymous functions (#324)
    var lazy_seen = $""
    for x in span6.lazy.map({ $0 * $0 }).filter(is_odd) {
        lazy_seen += String(x)
        lazy_seen += ","
    }
    let plus = span6.lazy.filter { $0 > 4 }
    var lazy_sum:int64 = 0
    for x in plus.map({ (n:int64):int64 in n + 100 }) { lazy_sum += x }
    println(lazy_seen, " ", lazy_sum)
    var fib_walk = fib_upto(50)                       // an Iterator, walked in part, then on (#326)
    let fib0 = fib_walk.next()
    var fib_seen = $""
    for x in fib_walk {
        fib_seen += String(x)
        fib_seen += ","
    }
    var tick = Iterator(3) {
        if $0 == 0 { return none }
        $0 -= 1
        return $0
    }
    var ticks:int64 = 0
    for t in tick { ticks += t + 1 }
    println(fib0, " ", fib_seen, " ", ticks)
    var odd_squares = fib_upto(100).lazy.filter(is_odd).lazy.map({ $0 * $0 })   // an Iterator made lazy (#328)
    var squares_seen = $""
    for x in odd_squares {
        squares_seen += String(x)
        squares_seen += ","
    }
    println(squares_seen)
    let digits_list:$[int64] = $[3, 1, 4, 1, 5]           // eager map, filter, reduce and flatMap (#329)
    println(digits_list.map { $0 * 10 }, " ", digits_list.filter(is_odd), " ", digits_list.reduce(0) { $0 + $1 }, " ", digits_list.flatMap { $[$0, $0] })
    println(span6.map { $0 + 1 }, " ", fib_upto(30).filter({ $0 > 2 }).map({ $0 * $0 }), " ", count_from(4).reduce(0) { $0 + $1 })
    println(stock.map { v in v * 10 }, " ", stock.filter { v in v > 3 }, " ", stock.reduce(0) { acc, v in acc + v })   // a Dictionary's and a Set's (#330)
    println(digit_set.map { $0 % 3 }, " ", digit_set.filter(is_odd), " ", digit_set.reduce(0) { acc, e in acc + e })
    println(stock.mapWithKey { k, v in String(k) + "!" }, " ", stock.filterWithKey { k, v in v < 5 }, " ", stock.reduceWithKey($"") { acc, k, v in acc + String(k) })   // the key first (#331)
    println(stock.flatMapWithKey(twin))               // each Dictionary merged (#332)
    var spare = ${2, 7}                               // a Set's pretty, typename, reserve and clear (#336)
    let spare_text:String = spare.pretty
    println(spare.pretty, " ", spare_text.count, " ", spare.typename)
    spare.reserve(8)
    spare.clear()
    println(spare, " ", spare.count)
    var shelf = stock.copy()                          // a Dictionary's find, pretty, typename, reserve and clear (#337)
    let pear:int64^ := shelf.find("pear")
    if pear != nullptr { pear^ += 100 }
    let shelf_text:String = shelf.pretty
    println(shelf.pretty, " ", shelf_text.count, " ", shelf.typename, " ", shelf.find("plum") == nullptr)
    shelf.reserve(8)
    shelf.clear()
    println(shelf, " ", shelf.count)
    var restock:Dictionary<String, int64> = ${"pear": 1, "plum": 4}   // merge and merging (#338)
    println(stock.merging(&restock), " ", stock.merging(&restock) { a, b in a + b })
    shelf.merge(&restock)
    shelf.merge(stock.copy()) { a, b in a * 10 + b }
    println(shelf)
    println(shelf.contains(4), " ", shelf.firstKey(3), " ", shelf.lastKey { v in v > 3 }, " ", shelf.containsWithKey { k, v in v > 20 }, " ", shelf.lastKeyWithKey { k, v in v < 10 })   // contains, firstKey and lastKey (#339)
    println(shelf.lastKey(4) ?? $"none", " ", shelf.firstKey(9) ?? "none", " ", restock.firstKey(4) ?? $"two", " ", shelf.lastKey(3) ?? restock.firstKey(1)!)   // ?? of an Optional that owns (#340)
    let pending:int64? = none                         // none in let and assignment (#341)
    var tag:String? = $"new"
    var outcome:Result<int64, String> = ok(1)
    println(pending, " ", tag, " ", outcome)
    tag = none
    outcome = err($"late")
    var marks:Dictionary<String, int64?> = ${"ann": 90, "bob": 70}
    marks["bob"] = none
    println(tag ?? $"untagged", " ", outcome, " ", marks)
    let rolls:$[int64] = $[3, 6, 2, 6, 1]             // an Array's contains, firstIndex and lastIndex (#342)
    let names:$[String] = $[$"ann", $"bob", $"ann"]
    println(rolls.contains(6), " ", rolls.firstIndex(6), " ", rolls.lastIndex(6), " ", rolls.firstIndex { $0 < 3 }, " ", rolls.firstIndex(9) ?? -1)
    println(names.lastIndex("ann"), " ", names.contains($"bob"), " ", names.firstIndex { n in n.count > 3 }, " ", names.lastIndex { $0.count == 3 })
    let gaps:$[int64?] = $[4, pending, 7]               // == of an Optional (#343)
    let gaps2:$[int64?] = $[4, none, 7]
    println(pending == none, " ", tag == $"untagged", " ", marks["ann"]! == 90, " ", marks.firstKey(none), " ", rolls.firstIndex(6) == 1, " ", gaps.lastIndex(none), " ", gaps == gaps2)
    let digits:$[Result<int64, String>] = $[parse_digit('4'), parse_digit('?'), 7]   // == of a Result (#344)
    println(outcome == err("late"), " ", parse_digit('7') == 7, " ", good != bad, " ", digits.firstIndex(7), " ", digits.contains(ok(5)), " ", outcome != err($"early"))
    println(a == item.num(5), " ", b != item.text($"hi"), " ", c == a, " ", items.contains(item.text($"in an Array")), " ", item.none == item.none, " ", items.firstIndex(item.none))   // == of an enum with values (#345)
    let bush = shrub.twigs($[shrub.leaf(2), shrub.twigs($[shrub.leaf(3), shrub.leaf(4)])])
    println(bush, " ", leaves(&bush), " ", bush == bush.copy())
    var fields:Dictionary<String, doc> = ${:}
    fields["title"] = doc.word($"kc")
    var empty:Dictionary<String, doc> = ${:}
    fields["body"] = doc.fields(empty)
    let page = doc.fields(fields)
    println(page, " ", page == page.copy(), " ", page != doc.word($"kc"))
    var made = Array<String>()                          // Array<T>() and Dictionary<K, V>() (#349)
    made += $"first"
    let scores = Dictionary<String, int64>()
    println(made, " ", scores, " ", doc.fields(Dictionary<String, doc>()), " ", Array<int64>().count)
    let trio = Array<int64>([2, 7, 1])                  // Array<T>([...]), Array<T>(&a) and Array<T>(n) (#350)
    var quad = Array<int64>(&trio)
    quad += 8
    println(trio, " ", quad, " ", Array<String>(2), " ", Array<int64>(3))
    let pantry = Dictionary<String, int64>({"fig": 2, "kiwi": 4})
    var larder = Dictionary<String, int64>(&pantry)     // Dictionary<K, V>({...}) and Dictionary<K, V>(&d) (#351)
    larder["fig"] = 9
    println(pantry, " ", larder, " ", larder == pantry)
    let guessed = Array([5, 3, 8])                      // Array([...]) with T inferred (#352)
    println(guessed, " ", Array([$"x", $"y"]), " ", guessed.count)
    var echoed = Array(&quad)                           // Array(&a) with T inferred (#353)
    echoed += 1
    println(quad, " ", echoed)
    var sq4 = [1, 4, 9, 16]                             // fixed arrays (#354)
    sq4[3] = 25
    let board2:[[int64](2)](2) = [[1, 2], [3, 4]]
    let zeros3 = [uint8](3)
    var sum_sq = 0
    for v in sq4 { sum_sq += v }
    println(sq4[3], " ", sq4.count, " ", board2[1][0], " ", board2.count, " ", zeros3.count, " ", sum_sq, " ", sq4.size)
    var from_sq = Array(sq4)                            // Array<T>(a) and Array(a) of a fixed array (#355)
    from_sq += 36
    println(from_sq, " ", Array<int64>(sq4).count)
    var tr:tray = {"eggs", [6, 12, 0]}
    tr.slots[2] = 18
    println(tr, " ", tr.slots.count, " ", tr.slots[2])
    double_all(sq4, sq4.count)
    println(total_of(sq4, sq4.count), " ", sq4[0], " ", total_of(tr.slots, 3))
    hits[1] += 2
    println(weekdays[2], " ", weekdays.count, " ", hits[1], " ", total_of(hits, hits.count))
    let prism = hull.sides([3, 4, 5])
    if let sides(s) = prism { println(prism, " ", s[2], " ", prism.sides.count, " ", prism == hull.sides([3, 4, 5])) }
    let sqp:[int64](4)^ := &sq4
    sqp^[1] = 7
    println(first_of(&sq4), " ", sqp^[1], " ", sqp^.count, " ", sq4[1])
    println(add_up(&sq4, sq4.count), " ", add_up(&tr.slots, 3))
    var aboard:crew = {"kelvin", [$"ann", $"bob"]}
    aboard.names[1] += "!"
    let backup = aboard.copy()
    aboard.names[0] = $"cy"
    println(aboard, " ", backup.names[0], " ", backup.names[1].count)
    hail(aboard.names, 2)
    println(aboard.names[1], " ", letters_in(aboard.names, 2), " ", letters_in(backup.names, 2))
    let width5:int64 = sq4.count + 1
    var strip = [uint8](width5)                          // a count C computes, a VLA (#366)
    strip[width5 - 1] = 9
    println(strip.count, " ", strip[width5 - 1], " ", strip[0])
    var grid2:[[int64](width5)](2)                       // a count C computes within another (#367)
    grid2[1][width5 - 1] = 4
    println(grid2.count, " ", grid2[0].count, " ", grid2[1][width5 - 1])
    var rows2:$[[int64]] = $[[1, 2], [3]]                // [T] in $[...] an Array, its lists Arrays (#369)
    rows2[1] += 4
    println(rows2, " ", rows2[1].count, " ", Array([[5], [6, 7]]))
    var pairs = [[1, 2], [3, 4], [5, 6]]
    println(rows_sum(pairs, pairs.count), " ", pairs[2][1])
    var counting = Iterator(-1) { $0 += 1; return $0 }   // x.prefix(n), x.prefix { ... }: take, takeWhile (#372)
    var firsts = counting.prefix(10).prefix { $0 * $0 < 30 }
    let smalls = $[$"a", $"bb", $"ccc"].prefix { $0.count < 3 }
    println(firsts.map { $0 }, " ", smalls, " ", $"kelvin".prefix(3), " ", ${3, 1, 4}.prefix(2))
    let naturals = 0...                                  // Range<T>: a value, a Sequence (#373)
    let octets3:Range<uint8> = 1...3
    var evens3 = naturals.lazy.filter { $0 % 2 == 0 }.prefix(3)
    println(naturals, " ", octets3.map { $0 * 2 }, " ", naturals.prefix(4), " ", evens3.map { $0 }, " ", (..<4).reduce(0) { $0 + $1 })
    println(octets3.count, " ", naturals.contains(7), " ", octets3.contains(0))   // r.count, r.contains(x) (#374)
    println(octets3.lowerBound, " ", octets3.upperBound, " ", naturals.lowerBound)   // its bounds (#375)
    println(octets3 == 1...3, " ", octets3 != 1..<3, " ", naturals == 0...4)   // == and != (#376)
    println($[5, 6, 7, 8][octets3], " ", $"kelvin"[naturals.prefix(3)], " ", $[5, 6, 7][1...])   // xs[r] (#377)
    println(octets3.reversed().map { $0 * 10 }, " ", naturals.prefix(5).reversed().prefix(2).map { $0 })   // r.reversed() (#378)
    println(naturals.stride(3).prefix(3).map { $0 }, " ", (0..<10).stride(-4).map { $0 }, " ", octets3.stride(2).map { $0 })   // r.stride(n) (#379)
    var power3:int64 = 3
    power3 **= 4
    println(2 ** 10, " ", -2 ** 2, " ", 2.0 ** 0.5, " ", octets3.upperBound ** 2, " ", power3, " ", 3.pow(4), " ", 4.pow(13, 497))   // b ** e, b.pow(e, m) (#380)
    println((0 - power3).abs, " ", (-2.5).abs, " ", (power3 - 100).abs)   // x.abs (#381)
    println((0 - power3).sign, " ", (-0.0).sign, " ", (power3 - 81).sign, " ", (0.0 / 0.0).isNaN)   // x.sign, x.isNaN (#382)
    var bits3:float64 = -2.5
    bits3.sign = true
    bits3.exponent += 1
    println(bits3, " ", bits3.sign, " ", bits3.exponent, " ", bits3.significand, " ", bits3.sign ?? false)   // a float's fields (#383)
    println(bits3.isFinite, " ", bits3.isInfinite, " ", (1.0 / 0.0).isInfinite, " ", (0.0 / 0.0).isFinite)   // x.isInfinite, x.isFinite (#384)
    let ♾️ = 1.0/0.0
    let 時間 = 60 * 60
    println(♾️, " ", 時間, " ", ♾️.isInfinite, " ", 時間 * 24)   // names past ASCII, arithmetic of literals (#385)
    var fell:String = $""
    for k in 0..<4 {
        switch k {                                    // fallthrough, on into the next case (#386)
        case 3:
            fell += "three "
            fallthrough
        case 2:
            fell += "two "
            if k == 2 { fallthrough }
        case 1: fell += "one "
        default: fell += "| "
        }
    }
    println(fell)
    var bset = Bits()                                 // Bits, each bit a bool by its place (#387)
    bset[dark] = true
    bset[1] = !!1
    bset[1] |= false
    bset.flip(2)
    let bmask = Bits(12)
    bset <<= 1
    println(bset, " ", bset[7], " ", bset.value as int64, " ", bset & bmask, " ", bset | bmask)
    println(bset ~ bmask, " ", ~bmask == bmask, " ", bset >> 2, " ", 1 << 3)
    var rounds = 0
    for _ in 0..<3 { rounds += 1 }
    let threes = $[4, 5, 6]
    println(but_first(1, $"unseen", 7), " ", rounds, " ", threes.map { _ in 1 }, " ", threes.reduce(0) { acc, _ in acc + 1 })
    let box1:parcel = {parcel.wrap.ribbon(2), {3, 4}}
    let side:parcel.dims = {5, 6}
    println(box1, " ", box1.cost(), " ", side.area(), " ", box1.w.ribbons(), " ", parcel.wrap.plain)
    struct leg { from: int64; to: int64 }              // types defined in a block (#390): the block's, _kv_main_leg in C
    enum heading { north, south }
    let trip:leg = {2, 9}
    let way = south
    var legs = $[trip]
    if true {
        enum heading { east, north }
        println(north)
    }
    println(trip, " ", legs, " ", way, " ", north, " ", trip.to - trip.from)
    let hi_bytes:cstr := "hi"
    for c in "hi" { print(c) }                        // a cstr's bytes: a literal's C's chars, a cstr's u8s (#390)
    for c in hi_bytes { print(" ", c) }
    println()
    return 0
}
