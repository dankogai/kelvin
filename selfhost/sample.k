// sample.k - a program of the subset kc reads, beside kc itself: the
// bootstrap builds it with kelvinc and with kc's last stage, and their
// output must be the same. It uses libc as C does (#207).
#import <stdlib.h> as C
#import <string.h> as C
#import <stdio.h> as C
#import <time.h> as C
#import <IO>                                          // f.lines, f.write (#450)
#import <JSON>                                        // modules/JSON.kh, and libkJSON.a beside it (#516)
#import <Rational>                                    // modules/Rational.k, a module's source, which names BigInt (#542)
#import <math>                                        // modules/math.k: its typealias, C's names, Self(x) (#550)
#import <math.h> as C

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

let word_of(n:int64):Result<String, int64> {    // ?? of a Result (#407)
    if n == 1 { return ok($"one") }
    return err(n)
}

let digit_shown(r:Result<int64, String>):int64 {    // ok(v) where a parameter takes it (#413)
    return r ?? -1
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
let twice_global:(int64):int64 := twice                // a global of an overload, picked by its type, its function declared first (#537)
let pick_twice():(int64):int64 { return twice }
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
    static let flipped(x:int64, y:int64):Self { (Self){.y = x, .x = y} }   // (T){...}, C's compound literal, and .name = (#418)
    let doubled_sum():int64 { .scaled(2).sum() }      // .m(a) of self (#444)
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
    for c in s^.codepoints {
        cs += c
    }
    var r:String = $""
    var i:int64 = cs.count as int64 - 1
    while i >= 0 {
        r += cs[i]
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
    var bump_twice():int64 {                            // .m(a), self's method (#444)
        .bump(1)
        return .bump(1)
    }
}
struct link {                                         // a list, which for walks along next (#444)
    value: int64
    next:  link^
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
let apply_twice(f:(int64):int64, x:int64):int64 { f(f(x)) }   // a parameter of a function type (#428)
struct dispatch { name: cstr; op: (int64):int64 }    // a member of one, called as s.op(x)
inline let cube(n:int64):int64 { n * n * n }            // inline (#392): C's static inline
let bump_by(a:int64^ restrict, b:const int64^ restrict) { a^ += b^ }   // restrict (#393): C's T *restrict
static_assert(dark == 6, "dark follows middle = 5")    // static_assert (#394): C's _Static_assert
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

enum { SAMPLE_LIMIT = 4 };                            // C's constants, with C's ; (#451)
struct bounds { lo: int64; hi: int64; };
let evens(n:int64):Array<int64> {                      // Array<T> as a type, as $[T] (#451)
    var xs:Array<int64> = Array<int64>()
    for i in 0..<n { xs += i * 2 }; return xs
}
let handed_back(s:String):String { return s }           // s moves in and out again (#441)
let open(path:const uint8^, flags:int32, ...):int32;   // C's, declared in Kelvin, variadic (#453)
extern var optind:int32;                               // C's getopt index, declared for Kelvin (#459)
static var sample_calls:int32 = 0                      // static, C's: this file's alone (#459)
static let sample_bump():int32 {
    static var times:int32                             // a local that lives on
    times += 1
    sample_calls += 1
    return times
}
let thrice_va(n:int64, ...):int64                      // a prototype, its body after main
let tally_sum(d:const ${String: int64}^):int64 {       // ${K: V}, Dictionary<K, V> for short (#460)
    var n = 0
    for k, v in d^ { n += v * k.count as int64 }
    return n
}
union pun { u: uint32; f: float32; b: [uint8](4) }    // C's types: a union, struct T, struct T; (#453)
struct chain_node { value: int32; next: struct chain_node^ }
struct timespec;
struct punned { p: union pun; n: int32 }
let chain_head(l:const struct chain_node^):int32 { l^.value }
let moment():timespec { return {1, 2} }
let digit_of(c:uint8):Result<int64, String> {         // try passes the err up (#449)
    if c < '0' || c > '9' { return Result<int64, String>.err($`not a digit: ${c}`) }
    return (c - '0') as int64
}
let digits_sum(s:cstr):Result<int64, String> {
    var sum:int64 = 0
    for c in s { sum += try digit_of(c) }
    return sum
}
let label_of(n:int64):Result<String, int64> {
    if n < 0 { return err(n) }
    return $`#${n}`
}
let labelled(n:int64):Result<String, int64> {
    var s = try label_of(n)
    s += "!"
    try label_of(n + 1)
    return s
}
let halved(n:int64):int64? {
    if n % 2 != 0 { return Optional<int64>.none }
    return Optional<int64>.some(n / 2)
}
let quartered(n:int64):int64? { return try halved(try halved(n)) }

let framed(b:const Bytes^):Bytes {                    // a Bytes (#439): a borrow in, a new one out
    var r = Bytes("[")
    r += b
    r += ']'
    return r
}

struct op_money;                                        // a struct's operators (#42, #135, #380), kc's (#471)
let +(a:op_money, b:op_money):op_money
struct op_money { cents: int64 }
let +(a:op_money, b:op_money):op_money { (op_money){a.cents + b.cents} }
let -(a:op_money, b:op_money):op_money { (op_money){a.cents - b.cents} }
let -(a:op_money):op_money { (op_money){-a.cents} }
let *(a:op_money, k:int64):op_money { (op_money){a.cents * k} }
let *(a:op_money, x:float64):op_money { (op_money){(a.cents as float64 * x) as int64} }
let *(k:int64, a:op_money):op_money { a * k }
let ==(a:op_money, b:op_money):bool { a.cents == b.cents }
let !=(a:op_money, b:op_money):bool { !(a == b) }
extend op_money {
    static let <(a:Self, b:Self):bool { a.cents < b.cents }
    static let **(a:Self, k:int64):Self { (Self){a.cents * a.cents * k / k} }
}
let >(a:op_money, b:op_money):bool { b < a }
let |(a:op_money, b:op_money):op_money { (op_money){a.cents | b.cents} }   // bitwise (#502)
let ~(a:op_money, b:op_money):op_money { (op_money){a.cents ~ b.cents} }
let ~(a:op_money):op_money { (op_money){~a.cents} }
let <<(a:op_money, n:int64):op_money { (op_money){a.cents << n} }
enum op_case { nil; val: int64 }
let +(a:op_case, b:op_case):op_case {
    if a.is(val) && b.is(val) { return {.val = a.val + b.val} }
    return op_case.nil
}
let op_made():op_case { return {.val = 7} }
struct op_owner { name: String; n: int64 }
let +(a:op_owner, b:op_owner):op_owner {
    var c = a.name.copy()
    c += &b.name
    return {c.copy(), a.n + b.n}
}
struct at_rect { w: f64; h: f64 }                       // attributes (#473)
struct at_temp { kelvin: f64 }
struct at_person { name: String; age: i64 }
enum at_shape { none; side: f64 }
let at_rect.area:f64 { .w * .h }
static var at_rect.made:i64 = 0
extend at_rect {
    let big:bool { self.area > 5.0 }
    let twice:Self { (Self){.w * 2.0, .h * 2.0} }
    let doubled:f64 { .twice.area }
    static let unit:Self = {1.0, 1.0}
    static var scale:i64 = 2
    static let square(s:f64):Self {
        Self.made += 1
        return {s, s}
    }
}
extend at_temp {
    var celsius:f64 {
        get { .kelvin - 273.15 }
        set(v) { .kelvin = v + 273.15 }
    }
    var warm(by:f64) {
        .celsius = .celsius + by
        .celsius += 1.0
    }
}
extend at_person {
    var title:String {
        get {
            var t = $"Dr. "
            t += &.name
            return t
        }
        set(v) { .name = v.copy() }
    }
    let older:Self { (Self){.name.copy(), .age + 1} }
}
extend at_shape {
    let size:f64 { .is(side) ? .side : 0.0 }
}
struct sb_grid { w: i64; cells: [i64](6) }              // subscripts (#475)
extend sb_grid {
    let [](i:i64):i64 { .cells[i] }
    var [](r:i64, c:i64):i64 {
        get { .cells[r * .w + c] }
        set(v) { .cells[r * .w + c] = v }
    }
    let total():i64 {
        var t = 0
        for i in 0..<6 { t += self[i] }
        return t
    }
}
let sb_grid[](name:cstr):i64 { name[0] as i64 }
let sb_grid[](i:i32):i64 { -1 }
let sb_bump(p:sb_grid^) { p^[0, 1] += 10 }
let sb_corner():sb_grid { var g:sb_grid = {2}; g[1, 1] = 4; return g }
enum sb_box { many: Array<i64>; one: i64 }
let sb_box[](i:i64):i64 { .is(many) ? .many[i] : .one }
struct sb_names { xs: Array<String> }
extend sb_names {
    var [](i:i64):String {
        get { .xs[i].copy() }
        set(v) { .xs[i] = v.copy() }
    }
    let [](k:String):i64 { k.count as i64 }
}
let sb_made():sb_names { return {$[$"m"]} }
let an_norm(v:{x:f64, y:f64}):f64 { v.x * v.x + v.y * v.y }   // types with no tag (#476)
let an_pair(n:i64):{n:i64, s:String} { return {n, String(n)} }
struct an_hold { at: {x:f64, y:f64}; tags: Array<{n:i64, s:String}> }
enum ec_shape { none; dot: i64; pair: {x:i64, y:i64}; tag: {s:String, n:i64} }   // a case's tag, {a, b} of a struct case (#477)
let ec_mk(n:i64):ec_shape { ec_shape.tag({String(n), n}) }
let num_wide(x:i8):i64 { return x as i64 + 1 }         // overloads of the rest of the integers (#472)
let num_wide(x:u64):i64 { return (x / 2) as i64 }
let num_wide(x:i128):i64 { return (x >> 100) as i64 }
struct num_pack { a: i8; b: u16; c: uint64; d: int128 }
struct ne_none { }                                       // an empty struct, zeroed by {} (#498)
struct ne_after { e: ne_none; n: i64 }
let trail_apply(n:int64, f:(int64):int64):int64 { return f(n) }      // a function trailing a plain call, sort and reverse (#470)
let trail_above(n:int64):bool { return n > 0 }
let trail_shorter(a:String, b:String):bool { return a.count < b.count }
let trail_says():int64 { return trail_apply(2) { $0 * 3 } }

struct fw_w { n: u64 }                                  // called before they are written (#505)
extend fw_w {
    static let +(a:Self, b:Self):Self { fw_w.of(a.n + b.n) }
    let twice():Self { self.half().scaled(4) }
    static let of(n:u64):Self { (Self){n} }
    let half():Self { (Self){self.n / 2} }
    let scaled(k:u64):Self { (Self){self.n * k} }
}
let fw_first(n:i64):i64 { fw_later(n) + 1 }
let ln_total(a:lent op_owner, b:lent op_owner):int64 { a.n + b.n }   // lent its caller's (#510)
struct cv_money { cents: i64 }                          // a converter of a struct is its attribute (#512)
extend cv_money {
    let i64:i64 { self.cents / 100 }
}
struct st_nines { n: i64 }                              // a type's own text as a String (#506)
let st_nines.string:String {
    var s = $""
    for i in 0..<.n { s += "9" }
    return s
}
// a type attribute of a number type (#148, #545), written before it is read, as a variable is
extend int64 {
    static let il_top:Self = 7
}

// a type's own text, one template (#53, #542): of a struct, of a union,
// and in extend, of text alone
struct tm_v2 { x: f64; y: f64 }
let tm_v2.cstr():cstr { `(${.x}, ${.y})` }
struct tm_line { a: tm_v2; b: tm_v2 }
union tm_bits { u: u64; f: f64 }
let tm_bits.cstr():cstr { `bits ${.u.hex}` }
struct tm_tag { n: i64 }
extend tm_tag {
    let cstr():cstr { "a tag" }
}
// aliases (#550): of a struct, of a number's type, of <math>'s own alias,
// and of a function type; an overloaded function given self in a
// number's method, and Self(x), the type's converter
struct ma_pair { a: f64; b: f64 }
typealias ma_p = ma_pair
typealias ma_real = float64
typealias ma_cx = complex64
typealias ma_op = (f64):f64
extend ma_p {
    static let ma_of(x:ma_real):Self { (Self){x, x * 2.0} }
    let ma_sum():ma_real { .a + .b }
}
let ma_apply(f:ma_op, x:f64):f64 { f(x) }
let ma_half(x:f64):f64 { x / 2.0 }
extend f64 {
    let ma_root():Self { sqrt(self) }
    let ma_twice():Self { Self(2) * self }
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
    println(len as int64, " ", abs(0 - 7) as int64, " ", home == nowhere)
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
    let blank = String()                              // an empty String, as kelvinc's (#414)
    println(blank.count, " [", blank, "]")
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
    var escaped_expected = $"Hié😀"
    escaped_expected += 0x7f                             // a codepoint appended (#528)
    println(escaped_text.count, " ", escaped_text == escaped_expected)
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
    if pear != nowhere { pear^ += 100 }
    let shelf_text:String = shelf.pretty
    println(shelf.pretty, " ", shelf_text.count, " ", shelf.typename, " ", shelf.find("plum") == nowhere)
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
    var said:Result<String, int64> = ok($"said")      // ?? of a Result (#407)
    println(outcome ?? 0, " ", good ?? 0, " ", parse_digit('?') ?? -1, " ", said ?? $"quiet", " ", word_of(1) ?? $"none", " ", word_of(2) ?? said.ok)
    said = err(3)
    println(said ?? $"quiet", " ", parse_digit('3') ?? 0 + 1, " ", word_of(5) ?? $"five")
    println(bad ?? good, " ", good ?? bad, " ", parse_digit('x') ?? parse_digit('2'), " ", bad ?? parse_digit('y'), " ", said ?? word_of(1), " ", word_of(4) ?? said, " ", bad ?? bad ?? 0)   // r ?? r2 (#408)
    println(pending ?? gaps[0], " ", gaps[1] ?? pending, " ", tag ?? none, " ", shelf.lastKey(4) ?? tag, " ", tag ?? shelf.lastKey(4), " ", shelf.firstKey(9) ?? none, " ", pending ?? gaps[1] ?? -1)   // a ?? b of two Optionals (#409)
    println(bad ?? ok(0), " ", good ?? err($"e"), " ", parse_digit('x') ?? ok(-1), " ", word_of(3) ?? err(4), " ", said ?? ok($"s"), " ", word_of(1) ?? err(0))   // r ?? ok(v), r ?? err(e) (#410)
    let nested:Result<int64?, String> = ok(none)
    let quiet:String? = "lit"
    println(good == ok(7), " ", bad != err("x"), " ", digit_shown(ok(3)), " ", digit_shown(err($"e")), " ", nested, " ", quiet)   // case words beside ==, as arguments, and none in ok (#413)
    let flagged:int64? = true
    let small:int32 = 6
    let measured:float64? = small
    let wide:Result<int64, String> = measured! > 5.0
    println(flagged, " ", measured, " ", wide, " ", flagged == false)   // a bool or a number of another kind where a number's T? goes (#415)
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
    var bset:u64 = 0                                  // an integer's bits, each a bool by its place (#530); Bits (#387) is no more (#532)
    bset.bits[dark] = true
    bset.bits[1] = !!1
    bset.bits[1] |= false
    bset.bits[2].flip()
    let bmask:u64 = 12
    bset <<= 1
    println(bset, " ", bset.bits[7], " ", u8(5).bits, " ", bset & bmask, " ", bset | bmask)
    println(bset ~ bmask, " ", ~bmask == bmask, " ", bset >> 2, " ", 1 << 3)
    var bgrow = BigInt([true, false, true, true, false])   // past 64 bits, a BigInt's (#531)
    bgrow.bits[100] = true
    bgrow.bits[dark].flip()
    let bgrow_bits = bgrow.bits
    var bones = 0
    for bit in bgrow_bits { if bit { bones += 1 } }
    let bcopy = BigInt(bgrow_bits)
    println(bgrow, " ", bgrow_bits.count, " ", bones, " ", bcopy == bgrow, " ", 0n.bits, " ", (-1n).bits)
    var bit_flag = true                               // a bool's flip (#454, #457), an integer's bits (#530)
    bit_flag.flip()
    var bit_word:u8 = 0b101
    bit_word.bits[1].flip()
    bit_word.bits[7] = true
    bit_word.bits[0] &= false
    println(bit_flag, " ", bit_word, " ", bit_word.bits[7], " ", bones.bits[1], " ", (bones + 1).bits[0])
    let bit_bools = bit_word.bits                     // its width of bools, an Array<bool>, and the way back
    var bit_ones = 0
    for bit in bit_word.bits { if bit { bit_ones += 1 } }
    println(bit_bools, " ", bit_ones, " ", u8(bit_bools), " ", i16(bit_word.bits), " ", u8([false, true, true]), " ", (bit_word + 1).bits.count)
    let cvp_text := "17"                              // v.i64 is i64(v) (#36, #533): of a bool, a number, an enum's value, text
    println(bit_flag.i64, " ", bit_flag.u8.typename, " ", bit_word.bits[7].f64, " ", (bit_ones > 1).i32, " ", bit_word.i64, " ", bit_word.i8, " ", 2.5.i32, " ", bit_word.bool)
    println(cvp_text.u8, " ", "2.5".f64, " ", dark.i64, " ", 300.u8, " ", bit_flag.bool, " ", bit_word.int64.hex, " ", bit_flag.i64 + 1)
    var cf_lo:int32 = 1, cf_hi:int32 = 9               // several declarators, C's for and comma (#458)
    var cf_sum:int64 = 0
    for (var i = 0, j = 4; i < j; i += 1, j -= 1) cf_sum += (i * j) as int64
    for (var k:int32 = cf_lo; k < cf_hi; k += 3)
        cf_sum += k as int64
    var cf_n2:link = {7, nowhere}
    var cf_n1:link = {5, &cf_n2}
    for (var at:link^ := &cf_n1; at != nowhere; at := at^.next) { cf_sum += at^.value as int64 }
    cf_lo = 0, cf_hi -= 1
    for (;;) { break }
    println(cf_sum, " ", cf_lo, " ", cf_hi)
    var do_n = 0                                      // do-while, p++, '\x6b' and "a" "b", more of C (#459)
    do {
        do_n += 1
    } while do_n < 3
    var do_p:uint8^ := "kelvin" as uint8^
    do_p++
    do_p++; do_p--
    sample_bump()
    println(do_n, " ", do_p^, " ", '\x6b', " ", "adjacent " "strings", " ", sample_bump(), " ", sample_calls, " ", optind >= 1)
    var tallies:${String: int64} = {"ann": 1}         // {k: v} where the type is written, ??=, !!=, ?? and !! (#460)
    tallies["bob"] ??= 2
    tallies["ann"] ??= 9
    tallies["ann"] !!= 3
    tallies ??= ${"cy": 4, "ann": 0}
    var picks:${int64} = {5, 6}                       // ${T}, Set<T> for short
    picks = Set<int64>({7, 5})
    let found := tallies.find("dan")
    println(tallies, " ", tallies !! ${"bob": 20}, " ", tally_sum(&tallies), " ", picks, " ", Set<int64>(&picks).count, " ", found.isNull, " ", ${"x": [1, 2]})
    let joins = $[$"a", $"b"]                         // xs.join(sep), xs.joined() (#461)
    var join_sep = $"+"
    println($[1, 2, 3].join(", "), " ", joins.joined(), " ", joins.join(join_sep), " ", $[$[1], $[2, 3]].join("|"), " ", $[true, false].joined("/"))
    var steps:[int32](3) = [10, 20, 30]                // x.size, x.cstr, p.addr, p.next and p.prev (#462)
    let at_step := &steps[1]
    alignas(8) let left:int32 = 1, right:int32 = 2
    println(joins.size, " ", (left + right).size, " ", at_step.next^, " ", at_step.prev^, " ", (at_step.next.addr - at_step.addr) as int64, " ", (3 < 4).cstr, " ", 2.5.cstr, " ", (&right).addr % 8 == 0)
    let parts = OS.splitext("kc.tar.gz")               // OS and SYS (#463), IO's OS
    let joined_path = OS.join("selfhost", "kc.k")
    println(OS.basename("a/b.k"), " ", parts.ok.ext, " ", OS.isabs("/tmp"), " ", joined_path, " ", OS.env("KC_SAMPLE_NO_SUCH") ?? "unset", " ", SYS.argv.count > 0, " ", OS.stat(".").ok.isdir, " ", parts.typename)
    let haystack = $"kelvin selfhost"                  // a String's methods, an IO's members (#464)
    var needle = $"self"
    var grows = $"k"
    grows.append("c!")
    grows.append(&needle)
    let ends = IO.pipe()
    var probe = IO("sample_probe.tmp", "w")
    probe.write("abcdef")
    probe.close()
    var reread = IO("sample_probe.tmp", "r")
    var chunks = 0
    for piece in reread.read(4) { chunks += 1 }
    println(haystack.find(&needle), " ", haystack.starts("kel"), " ", haystack.ends("host"), " ", grows, " ", ends.reader.fd > 2)
    println(chunks, " ", reread.stat.size, " ", reread.basename, " ", reread.remove(), " ", needle.bytes^.count)
    let held_path := "sample_held.tmp"                // an IO an expression gives, held for the loop (#466)
    var held_out = IO(held_path, "w")
    held_out.print("a\nbc\n")
    held_out.close()
    var held_lines = 0
    for line in IO(held_path).lines { held_lines += line.ok.count as int64 }
    println(held_lines, " ", OS.remove(held_path))
    var rounds = 0
    for _ in 0..<3 { rounds += 1 }
    let threes = $[4, 5, 6]
    println(but_first(1, $"unseen", 7), " ", rounds, " ", threes.map { _ in 1 }, " ", threes.reduce(0) { acc, _ in acc + 1 })
    let box1:parcel = {parcel.wrap.ribbon(2), {3, 4}}
    let side:parcel.dims = {5, 6}
    println(box1, " ", box1.cost(), " ", side.area(), " ", box1.w.ribbons(), " ", parcel.wrap.plain)
    struct leg { from: int64; to: int64 }              // types defined in a block (#391): the block's, _kv_main_leg in C
    enum heading { north, south }
    let trip:leg = {2, 9}
    let way = south
    var legs = $[trip]
    if true {
        enum heading { east, north }
        println(north)
    }
    println(trip, " ", legs, " ", way, " ", north, " ", trip.to - trip.from)
    var tally_r:int64 = 1
    let step_r:int64 = 41
    bump_by(&tally_r, &step_r)
    static_assert(light + middle == 5)
    println(alignof(int64), " ", trip.align, " ", tally_r.align)   // alignof(T), x.align (#395)
    alignas(32) var lane:[uint8](16)                     // alignas (#396): C's _Alignas
    lane[0] = 9
    println(lane[0], " ", lane.count)
    var lane2:typeof(tally_r) = 40                      // typeof(x) (#398), C23's
    lane2 += 2
    println(lane2, " ", 7 as typeof(int64))
    println(cube(3), " ", side.area(), " ", tally_r)
    let hi_bytes:cstr := "hi"
    for c in "hi" { print(c) }                        // a cstr's bytes: a literal's C's chars, a cstr's u8s (#390)
    for c in hi_bytes { print(" ", c) }
    println()
    let hop = (leg){.to = 8, .from = 3}
    let reach:int64 = (leg){1, 4}.to
    println(point.flipped(1, 2), " ", hop, " ", reach, " ", (point){5, 6}.sum())
    let odds = ([int64])[1, 3, 5]                      // ([T])[a, b], an array's compound literal (#419)
    let squares = ([[int64]])[[1, 2], [3, 4]]
    let third:int64 = ([int64](4))[7, 8, 9][2]
    let summed:int64 = total_of(([int64])[4, 5, 6], 3)
    println(odds.count, " ", odds[2], " ", squares[1][0], " ", squares.count, " ", third, " ", summed)
    let sized:int64 = sizeof (point){1, 2}             // sizeof(T), sizeof x (#420): C's, an int64
    let cells:int64 = sizeof(odds) / sizeof(int64)
    println(sizeof(point), " ", sizeof(int32^), " ", sizeof odds[0], " ", cells, " ", sized, " ", sizeof(shade), " ", sizeof shade_name)
    let anchor:point = {3, 4}
    println(sizeof(anchor.type), " ", sizeof(anchor.x.type), " ", sizeof(odds[0].type), " ", sizeof(anchor.type^))   // sizeof(x.type) (#421)
    var mirror:anchor.type = (anchor.type){anchor.y, anchor.x}   // x.type where a type goes (#422)
    let narrow = 300 as anchor.x.type
    let cast_x:[anchor.y.type](2) = [narrow, mirror.x]
    println(mirror, " ", narrow, " ", cast_x[1], " ", sizeof cast_x)
    var widened_n:narrow.type = narrow * 2               // x.type of a local whose type is inferred (#423)
    let odd_cells:[odds[0].type](2) = [odds[1], odds[2]]
    var odd_list:$[narrow.type] = $[narrow]
    odd_list += widened_n
    println(widened_n, " ", sizeof widened_n, " ", odd_cells[1], " ", sizeof odd_cells, " ", odd_list)
    let halved_list = odd_list.map { ($0 as $0.type) / 2 }      // $0.type of an anonymous function (#424)
    let anchors:$[point] = $[anchor, mirror]
    let swapped = anchors.map { ($0.type){$0.y, $0.x} }
    let tripled = odd_list.map { v in (v as v.type) * 3 }
    println(halved_list, " ", swapped, " ", tripled)
    let fixed_x:const cast_x.type = [narrow, 7]          // const xs.type of an array, [const T](N) (#425)
    var kept:[const int64](2) = [odds[0], odds[2]]
    println(fixed_x[1], " ", sizeof fixed_x, " ", kept[1], " ", kept.count)
    println(anchor.typename, " ", kept.typename, " ", halved_list.typename, " ", shade_name.typename, " ", 42.typename, " ", "a".typename)   // x.typename (#426)
    let clamped = { (k:int64):int64 in k <= 0 ? 30 : k }(odds[0] - 10)   // an anonymous function as a value, called (#428)
    let bump:(int64):int64 := { $0 + 1 }
    let twice_of := doubled                              // a function's name, a value of its type
    let step:dispatch = {"half", { $0 / 2 }}
    println(clamped, " ", apply_twice(bump, 5), " ", apply_twice(twice_of, 3), " ", step.op(40), " ", bump.typename)
    let twice_at := &doubled                             // &f of a function's name is the function itself (#536)
    var fn_list = $[&doubled, doubled]
    let step_at:dispatch = {"twice", &doubled}
    println(twice_at(4), " ", apply_twice(&doubled, 3), " ", fn_list[0](5), " ", step_at.op(6), " ", twice_at.typename, " ", twice_at == doubled)
    let twice_int:(int64):int64 := twice                 // of an overloaded name, the one of the type written (#41, #537)
    var twice_pt:(point):point := twice
    twice_pt := twice
    println(twice_int(21), " ", apply_twice(twice, 5), " ", twice_pt(anchor), " ", twice_global(8), " ", pick_twice()(9))
    let hex_text = $"0x1f"
    println(int64("42"), " ", int32("ff", 16), " ", float64("1.5"), " ", uint8("300"), " ", int64(hex_text, 16), " ", int64(2.7), " ", float32(odds[2]))   // converters (#429)
    let short_u8:u8 = u8("300")                           // kelvinc's short type names (#430)
    let short_half:f64 = f64(odds[2]) / 2.0
    println(short_u8, " ", short_half, " ", sizeof(i32), " ", (7 as u32).typename, " ", i64(short_u8) * 2)
    let held_len:size_t = strlen(String(4096).cstr)       // a pointer into a temporary, held for the call (#245, #433)
    println(held_len, " ", strlen($"kelvin".cstr), " ", String(12).cstr, " ", String(345).cstr[1], " ", atoi(String(7 * 6).cstr))
    let empty_text:cstr := ""                             // x.isEmpty (#434, #435): the count's 0; an iterator's false
    let empty_span:span = {3, 3}
    println(none_yet.isEmpty, " ", hex_text.isEmpty, " ", empty_text.isEmpty, " ", (3..<3).isEmpty, " ", (0...).isEmpty, " ", count_from(0).isEmpty, " ", empty_span.isEmpty, " ", fib_upto(10).isEmpty)
    var grown:$[int64] = $[1, 2, 3]                       // an Array's methods (#438), in place
    grown.append(4)
    grown.insert(0, 9)
    grown.remove(1, 2)
    grown.reserve(16)
    grown.compact()
    var words_in:$[String] = $[]
    words_in.append($"a")
    words_in.append(&hex_text)                            // a borrow, copied in
    words_in += &hex_text
    words_in.insert(1, String(5))
    println(grown, " ", words_in, " ", hex_text)
    words_in.clear()
    println(words_in.isEmpty)
    var octets = Bytes()                                  // a Bytes (#439): its bytes in place, compared, made a String
    octets.append(72)
    octets += "ey"
    octets += octets.copy()                               // what an expression gives, moved in
    octets.insert(0, Bytes([0x3e, 32]))
    octets.remove(4, 2)
    octets[2] = 'h'
    let octet_text = Bytes(&hex_text)
    let octet_list:$[Bytes] = $[Bytes(2), framed(&octet_text)]
    var octet_sum:int64 = 0
    for x in octets { octet_sum += x as int64 }
    println(octets, " ", octets.count, " ", octets.capacity >= octets.count, " ", octets[0], " ", octets.cstr, " ", framed(&octets), " ", octet_list, " ", octet_sum)
    println(octets == octets.copy(), " ", octets != octet_text, " ", octets < octet_text, " ", framed(&octets) >= octets, " ", String(&octet_text), " ", octet_text.string() ?? $"?", " ", Bytes(3).isEmpty, " ", Bytes().isEmpty)
    octets.clear()
    octets.compact()
    println(octets.count, " ", octets.isEmpty)
    var handed = $"handed"                               // moved out, dead until given anew (#441)
    let held:String? = handed
    handed = $"anew"
    let back = handed_back(handed)
    handed = $"again"
    println(held ?? $"?", " ", back, " ", handed)
    if let h = held { println(h, " ", h.count) }        // the value of an Optional, of a Result (#442)
    let nothing:String? = none
    if let h = nothing { println(h) } else if let t = octet_text.string() { println("text ", t) }
    var twice_box:tally_box = {5}
    var link_c:link = {3, nowhere}
    var link_b:link = {2, &link_c}
    var link_a:link = {1, &link_b}
    var linked:int64 = 0
    for l in &link_a { linked = linked * 10 + l^.value }
    let triangles = $[1, 2, 3].map { k in (1...k).map { j in (1...j).reduce(0) { $0 + $1 } } }   // one inside another (#444)
    println(point.of(1, 2).doubled_sum(), " ", twice_box.bump_twice(), " ", twice_box.n, " ", linked, " ", triangles)
    let shown := `${linked} ${1.5} ${linked > 100} ${handed} ${handed_back($"held")} ${point.of(3, 4)} ${triangles} ${`<${linked}>`}`   // templates (#445)
    let phrase = $`${shown}: ${handed} ${triangles.count} ${point.of(5, 6).pretty} \` \${x}
on a new line`
    println(shown, " ", phrase, " ", `plain`, " ", $`plain`)
    let numeral:cstr := "digits"                        // a cstr's count, a number's text (#447)
    println(numeral.count, " ", linked.dec, " ", linked.hex, " ", linked.oct, " ", linked.bin, " ", 2.5.hex, " ", `${linked.hex}`.count, " ", $`${(0 - 7).dec}`)
    println(digits_sum("123"), " ", digits_sum("1x3"), " ", labelled(4), " ", labelled(-1), " ", quartered(12), " ", quartered(6))
    var scratch = IO("sample_lines.tmp", "w")             // each line a Result, the text written by its kind (#450)
    scratch.write("one\n")
    scratch.write(&handed)
    scratch.write($"\nthree")
    scratch.print("\n", 4, " ", true)                    // an IO's print and println, as print's (#452)
    scratch.println(" ", point.of(5, 6), " ", $[7].pretty)
    scratch.flush()
    scratch.close()
    var lines_in = IO("sample_lines.tmp")
    var line_count = 0
    for r in lines_in.lines { if let line = r { line_count += line.count as int64 } }
    lines_in.rewind()
    for r in lines_in.lines { print(r.is(ok) ? "o" : "e") }
    remove("sample_lines.tmp")
    IO.stdout.print("[", lines_in.fd > 2, " ", $[1, 2].pretty.count, "]")
    let parsed = digits_sum("42")
    println(" ", line_count, " ", parsed.cstr, " ", quartered(8).cstr, " ", point.of(1, 2).cstr, " ", Bytes(&$"h\u{e9}llo").count)
    var nest = Array<Array<int64>>([[1, 2], [], [3]])
    var flags:[bool](SAMPLE_LIMIT + 1) = [false]
    flags[SAMPLE_LIMIT] = true
    let sp:bounds = {SAMPLE_LIMIT, SAMPLE_LIMIT * 2};
    println(evens(SAMPLE_LIMIT), " ", nest, " ", nest[1].count, " ", Array(['k', 'c']).typename, " ", flags[SAMPLE_LIMIT], " ", flags.count, " ", sp.hi, " ", SAMPLE_LIMIT.typename)
    var pn:union pun = {.f = 1.0}
    let pv:pun = {.u = 0x40000000}
    let cb:struct chain_node = {2, nowhere}
    var ca:struct chain_node = {1, &cb as struct chain_node^}   // as looser than &, as kelvinc's
    let cp := &ca:struct chain_node^
    let null_fd = open("/dev/null", 0)
    let pw:punned = {pn, 5}
    let when:struct timespec = moment()
    let cl = (struct chain_node){9, nowhere}
    println(pn, " ", pn.u.hex, " ", pv.f, " ", chain_head(&ca), " ", cp^.next^.value, " ", null_fd > 2, " ", -null_fd as int64 < 0, " ", thrice_va(2, "x", 4.5))
    println(pw, " ", sizeof(struct chain_node) == sizeof(chain_node), " ", sizeof(union pun), " ", cl.value, " ", when.tv_nsec, " ", $[pn, pv], " ", `${pv}`, " ", pw.p.typename)
    var tv = $[3, 1, 2]
    tv.sort { $0 > $1 }
    var tn = $[$"bob", $"al", $"christine"]
    let tb = tn.sorted(trail_shorter)
    let tm = tn.map { (var s:String):String in
        s += "!"
        return s
    }
    tn.sort()
    tn.reverse()
    if trail_above(trail_apply(1) { $0 }) { print("<") }
    let told:any^ := nowhere
    println(trail_says(), " ", trail_apply(1) { (x:int64):int64 in x + 10 }, " ", tv, " ", tv.sorted(), " ", tv.reversed(), " ", $[2, 1].sorted { $0 < $1 }.map { $0 * 10 })
    println(tb, " ", tm, " ", tn, " ", tn[0] > tn[1], " ", told == nowhere)
    var oa:op_money = {150}
    let ob:op_money = {275}
    oa += ob
    oa *= 2
    let oc = oa + ob
        - ob
    var og = $[ob, oa, oc]
    og.sort()
    var oe = op_case.val(1)
    oe += op_case.val(2)
    var ot:op_owner = {$"x", 1}
    ot += (op_owner){$"y", 2}
    let on:op_case = {.nil}
    println(oa, " ", oc.cents, " ", (-ob).cents, " ", (3 * ob).cents, " ", (ob ** 2).cents)
    println(ob * labs(-2), " ", ob * atof("1.5"), " ", oa < ob, " ", oa == ob, " ", oa != ob)
    println(og, " ", oe, " ", on, " ", ot, " ", og.sorted { $0 > $1 }[0].cents, " ", op_made().val)
    let n8:i8 = -5                                       // the rest of the integers (#472)
    let n16:int16 = -300
    let u16v:u16 = 65535
    let u64v:uint64 = 18446744073709551615
    let n128:i128 = i128("-170141183460469231731687303715884105727")
    let u128v:u128 = u128("340282366920938463463374607431768211455")
    println(n8, " ", n16, " ", u16v, " ", u64v, " ", n128, " ", u128v)
    println(n8.typename, " ", u128v.typename, " ", n8.size, " ", u128v.size)
    println(n8.abs, " ", n16.sign, " ", (n8 * 100).abs, " ", (-n8).size)
    println(n8.hex, " ", u16v.bin, " ", n128.hex, " ", u128v.bits[127], " ", u8("ff", 16), " ", u64("7"))
    println(`${n8} ${u64v} ${n128} ${u128v}`)
    println(num_wide(n8), " ", num_wide(u64v), " ", num_wide(n128), " ", (0x1p4).typename, " ", 0x1p4)
    let r64:Range<u64> = 1...3
    println(r64, " ", r64.count, " ", r64.count.typename)
    println($[n8, n8], " ", $[u64v], " ", u16v.bits.count, " ", n8.size.typename, " ", (num_pack){1, 2, 3, 4})
    let at_r:at_rect = {2.0, 3.0}                        // attributes (#473)
    if at_r.big { println(at_r.area, " ", at_r.doubled, " ", at_r.twice, " ", at_r.twice.area) }
    var at_t:at_temp = {300.0}
    at_t.celsius = 100.0
    at_t.celsius += 10.0
    let at_q := &at_t
    at_q^.warm(1.0)
    println(at_t.celsius, " ", at_q^.celsius)
    var at_p:at_person = {$"Ada", 36}
    let at_who = at_p.title
    let at_new = $"Grace"
    at_p.title = at_new
    println(at_who, " ", at_p.title, " ", at_p.older, " ", at_p.older.age, " ", at_p.title.count)
    println(at_shape.side(2.5).size, " ", at_shape.none.size)
    let at_s = at_rect.square(4.0)
    at_rect.scale += 1
    at_rect.scale = at_rect.scale * 2
    println(at_s, " ", at_rect.unit, " ", at_rect.unit.area, " ", at_rect.made, " ", at_rect.scale)
    var sb_g:sb_grid = {3}                               // subscripts (#475)
    sb_g[1, 2] = 7
    sb_g[0, 0] += 5
    sb_g[0, 0] *= 2
    println(sb_g[5], " ", sb_g[1, 2], " ", sb_g[0], " ", sb_g["A"], " ", sb_g[0 as i32], " ", sb_g.total())
    sb_bump(&sb_g)
    var sb_gs:[sb_grid](2) = []
    sb_gs[1][0, 0] = 3
    println(sb_g[1], " ", sb_gs[1][0], " ", sb_corner()[3], " ", `${sb_g[0, 0]}`)
    let sb_b = sb_box.many($[10, 20, 30])
    println(sb_b[1], " ", sb_box.one(4)[9])
    var sb_n:sb_names = {$[$"a", $"b"]}
    let sb_w = $"bee"
    sb_n[1] = sb_w
    sb_n[0] = "ay"
    let sb_k = $"four"
    println(sb_n[1], " ", sb_n[0], " ", sb_n[sb_k], " ", sb_n.xs, " ", sb_made()[0], " ", sb_n[1].count)
    var an_v:{x:float64; y:float64} = {3.0, 4.0}          // types with no tag (#476)
    var an_h:an_hold = {an_v, $[an_pair(1)]}
    an_h.tags += an_pair(22)
    let an_u:union{i:i32, f:f32} = {.f = 1.0}
    var an_e:enum{none, n:i64, txt:String} = {.txt = $"es"}
    println(an_norm(an_v), " ", an_v.typename, " ", an_h, " ", an_h.tags.typename, " ", an_u.i, " ", an_u, " ", an_e)
    an_e.n = 5
    let an_c = ({x:f64, y:f64}){1.0, 2.0}
    println(an_e, " ", an_e.typename, " ", an_c, " ", an_norm(an_c), " ", an_pair(3).s.count)
    var ec_s = ec_shape.pair({1, 2})                      // a case's tag, {a, b} of a struct case (#477)
    let ec_o:i64? = 4
    println(ec_s, " ", ec_s.case, " ", ec_s.case.typename, " ", ec_o.case, " ", ec_mk(7).case, " ", ec_mk(8))
    ec_s.tag = {$"t", 9}
    println(ec_s, " ", ec_s.case, " ", ec_s.tag.s, " ", ec_s.is(tag))
    let uc_e:u32 = 0xE9                                   // a codepoint is a u32 (#528), compared as one
    let uc_s = $"日本"
    var uc_n = 0
    for uc_c in uc_s.codepoints { if uc_c >= 0x65E5 && uc_c != uc_e { uc_n += 1 } }
    println(uc_e, " ", uc_s.codepoints[0], " ", uc_e > 'a', " ", int64(uc_e) + 1, " ", uc_n)
    var uc_a:$[u32] = $[uc_e, 0, 0x22]                    // codepoints inside a value
    let uc_f:[u32](2) = [0x70, 0x41]
    let uc_i:[i64](2) = [int64(2.5), 3]
    let uc_o:u32? = uc_e
    println(uc_a, " ", uc_f[1], " ", uc_i[0], " ", uc_o)
    var uc_w = [u32](4)                                   // a walk stops at a 0 (#480)
    uc_w[0] = uc_e
    uc_w[2] = 0x7A
    for uc_x in uc_f { print(uc_x, " ") }
    for uc_x in uc_w { print(" ", uc_x) }
    println()
    println(uc_f, " ", uc_i, " ", uc_w)                    // a fixed array is [a, b] (#481)
    var ne_a:ne_none                                       // an empty struct, and one after it, {} (#498)
    var ne_b:ne_after
    var ne_c:[ne_none](2)
    ne_b.n = 3
    println(ne_a.size, " ", ne_b.n, " ", ne_c.size)
    println(ne_c.count, " ", ne_c, " ", Array(ne_c).count)   // its declared count, where sizeof's is 0 / 0 (#499)
    var mo_s = $"mo"                                       // moved out once in an expression, given anew (#500)
    mo_s = handed_back(mo_s)
    let mo_o:String? = $"mo"
    println(mo_o == mo_s, " ", mo_s)                       // == wraps a copy, and mo_s stays (#500)
    let lo_a:op_owner = {$"a", 1}                          // an operand lent, its caller's (#501)
    let lo_b = lo_a + lo_a + (op_owner){$"b", 2}
    println(lo_a, " ", lo_b)
    var bw_m:op_money = {5}                                // a struct's bitwise operators (#502)
    bw_m <<= 2
    bw_m |= (op_money){1}
    println(bw_m.cents, " ", (~bw_m).cents, " ", (bw_m ~ (op_money){3}).cents)
    var lm_s = $"lm"                                       // a local owner moves into a literal (#503)
    let lm_p = (op_owner){lm_s, 5}
    println(lm_p)
    println(fw_first(3), " ", (fw_w.of(1) + fw_w.of(2)).n, " ", fw_w.of(8).twice().n)   // (#505)
    let st_a:st_nines = {300}
    var st_t = $`${st_a}`
    println(st_t.count, " ", (st_nines){3}, " ", `<${(st_nines){2}}>`)   // whole, and in `...` too (#506)
    let ln_a:op_owner = {$"la", 4}
    println(ln_total(ln_a, ln_a), " ", ln_total(ln_a, (op_owner){$"lb", 6}), " ", ln_a)   // a kept, a temporary held (#510)
    let cv_m:cv_money = {1234}
    println(i64(cv_m), " ", cv_m.i64)                    // (#512)
    let cl_n:i64 = 300
    println(u8(cl_n), " ", i8(0 - cl_n), " ", u64(0 - 1), " ", i32(0.0 - 3.9), " ", cl_n as u8)   // clamped, as #513; as wraps
    let bg_a = 2n ** 100 + 1                               // the prelude's BigInt, of BigInt.kh (#515)
    let bg_b = BigInt(0 - 12345)
    println(bg_a, " ", bg_a.hex, " ", bg_b * bg_b, " ", pow(bg_a, 3, 1000003n), " ", bg_a.gcd(6), " ", i64(bg_a), " ", bg_b < bg_a)
    var bg_bits = 5n                                       // a BigInt's bits (#531): b.bits, b.bits[n] where it is, BigInt(bools)
    bg_bits.bits[1] = true
    bg_bits.bits[70] |= true
    bg_bits.bits[0].flip()
    let bg_bools = bg_b.bits
    println(bg_bits, " ", bg_bits.bits[70], " ", bg_bits.bits[500], " ", bg_b.bits[500], " ", bg_bools.count, " ", BigInt(bg_bools) == bg_b)
    println(BigInt([true, false, true, false]), " ", (bg_bits + 1n).bits[0], " ", 5n.bits)
    let rx_e = $/(\d+)-(?<m>\d+)/g                         // and its RegExp, of RegExp.kh (#515)
    var rx_s = $"10-20 and 3-4"
    var rx_ms = rx_s.match(&rx_e)
    println(rx_ms.count, " ", rx_ms[1]["m"], " ", rx_s.replace(&rx_e, "$2:$1"), " ", rx_s.split($/\s+/))
    var rx_t = rx_s.replace(&rx_e) { $`<${$0.text[1]}>` }  // a function of each Match, which it owns
    println(rx_t, " ", rx_e.global, " ", rx_s.test(&rx_e))
    var js_j = JSON.parse("""
        {"name": "kelvin", "tags": ["c", 11], "n": 3}
        """)                                               // a module of modules/ (#516)
    js_j["n"] = JSON.number(4.0)
    js_j["tags"][0] = JSON.string($"C")
    println(js_j["name"].string, " ", js_j["tags"][1].number, " ", JSON.stringify(&js_j), " ", JSON.stringify(&js_j, js_doubled))
    println(JSON.stringify(&js_j.object["tags"], 1))
    var gr_s = $"e\u0301 ﬁ 👨‍👩‍👧 x"                   // a String's graphemes, each a String (#522)
    var gr_n = 0
    for gr_c in gr_s {
        if gr_c != ' ' { gr_n += 1 }
    }
    println(gr_n, " ", gr_s.count, " ", gr_s.codepoints.count, " ", gr_s[4], " ", gr_s[2..<5], " ", gr_s.find("x"), " ", gr_s.prefix(1), " ", gr_s[0] == "e\u0301")
    var ty_sum:u64 = 0                                 // for x:T in ..., a type written (#523), as kelvinc's #480
    for ty_n:u32 in gr_s { ty_sum += ty_n as u64 }
    var ty_cs:$[i64] = $[72, 105]
    var ty_t = $""
    for ty_c:u32 in ty_cs { ty_t += ty_c }
    for ty_i:u8 in 254...255 { ty_sum += ty_i as u64 }
    let ty_r = 1..<4
    for ty_j:i32 in ty_r { ty_sum += ty_j as u64 }
    println(ty_sum, " ", ty_t)
    var fe_five:[int32](5) = [1, 2, 3, 4, 99]          // a parameter's array to its count, a pointer to a 0 (#524)
    var fe_n = 0
    for fe_x in ([int32](3))[5, 6, 0] { fe_n += fe_x }
    for fe_i in (int64){2}..<4 { fe_n += fe_i as i32 }
    var fe_ended:[int32](4) = [7, 8, 0, 9]
    let fe_p:int32^ := &fe_ended[0]
    for fe_y in fe_p { fe_n += fe_y }
    println(fe_sum4(fe_five), " ", fe_n)
    var gc_cs:$[u32] = $[0x48, 0x69]                  // a String of codepoints, the first grapheme alone (#526)
    println(grapheme(0x65, 0x301, 0x41), " ", String.fromCodepoints(gc_cs), " ", grapheme(0xD800), " ", String.fromCodepoints())
    var cp_s = $"é1"                                    // a codepoint is a u32, with its properties (#527)
    var cp_t:u32 = 0
    for cp_c in cp_s.codepoints { cp_t += cp_c }
    let cp_e = cp_s.codepoints[0]
    println(cp_t, " ", cp_e.name, " ", (0x31 as u32).isNumber, " ", cp_e.upper.hex, " ", cp_s.codepoints)
    let tm_v:tm_v2 = {1.5, -2.0}                        // a type's own text, T.cstr() (#53, #542)
    let tm_l:tm_line = {{0.0, 0.0}, tm_v}
    var tm_b:tm_bits = {.f = 1.0}
    let tm_o:tm_v2? = tm_v
    let tm_t:tm_tag = {7}
    println(tm_v, " ", tm_v.cstr, " ", `<${tm_v}>`, " ", tm_l, " ", tm_b)
    println($[tm_v], " ", tm_o, " ", tm_t, " ", tm_v.cstr.count)
    let nm_n:i64 = 4                                    // a number's methods, of a literal too (#538, #542)
    let nm_m:i32 = 5
    let nm_s = 1 << 40
    println(nm_n.nm_twice(), " ", nm_m.nm_twice(), " ", 3.nm_twice(), " ", (1 << 40).nm_twice(), " ", (65536 * 65536).nm_twice(), " ", (-4).nm_twice())
    println(9.0.nm_half(), " ", nm_m.nm_twice().typename, " ", nm_s, " ", nm_n.nm_twice().nm_twice())
    println(tm_v.at_norm, " ", nm_n.at_sq, " ", 7.at_sq, " ", (1 << 20).at_sq)   // attributes written after main (#544), of a literal too (#548)
    let il_x = i32.max                                  // an integer type's limits (#545), and a number type's own attribute
    println(i8.min, " ", u8.max, " ", i64.max, " ", i128.min, " ", u64.min, " ", il_x.typename, " ", (i64.max - 1) / 2, " ", i64.il_top)
    println(f64.pi, " ", f32.pi, " ", f64.infinity, " ", f64.nan.isNaN, " ", f64.signalingNaN, " ", f64.radix, " ", f32.ulpOfOne.typename)   // a float's constants (#546)
    println(f64.greatestFiniteMagnitude, " ", f64.leastNormalMagnitude, " ", f64.leastNonzeroMagnitude, " ", f32.ulpOfOne, " ", f32.leastNonzeroMagnitude.hex)
    var rn_in = true                                    // T.random() (#547): what is drawn differs, so its bounds and its type are shown
    for rn_i in 0..<1000 {
        let rn_d = i64.random(1...6)
        let rn_u = u8.random(250...)
        let rn_f = f64.random()
        let rn_g = f32.random(-2, 2)
        if rn_d < 1 || rn_d > 6 || rn_u < 250 || rn_f < 0.0 || rn_f >= 1.0 || rn_g < -2.0 || rn_g >= 2.0 { rn_in = false }
    }
    let rn_r:Range<i16> = -3..<3
    let rn_s = i16.random(rn_r)
    println(rn_in, " ", rn_s >= -3 && rn_s < 3, " ", i64.random(7...7), " ", i64.random() != i64.random(), " ", u128.random().typename, " ", bool.random().typename, " ", f32.random(1.5).typename)
    let ma_z:ma_cx = ma_cx(3.0, 4.0)                    // <math> (#550): complex64, its alias of c64, and ours of that
    let ma_w = (c64){1.0, 2.0} * ma_z.conj()            // a type of a file imported, in a compound literal and in sizeof
    let ma_q:ma_p = ma_p.ma_of(ma_real(1.5))
    println(abs(ma_z), " ", ma_z.typename, " ", ma_w, " ", 1.0.i * 1.0.i, " ", 1.0 / ma_z, " ", sqrt(16.0), " ", 16.0.ma_root(), " ", 1.5.ma_twice())
    println(ma_q, " ", ma_q.ma_sum(), " ", ma_q.typename, " ", ma_apply(ma_half, 9.0), " ", sizeof(c64), " ", sizeof(ma_cx) == sizeof(complex32) * 2, " ", 2.0.pow(10.0), " ", floor(2.5))
    println(copysign(INFINITY, -1.0), " ", isnan(pow(ma_z, NAN).real) != 0, " ", fmax(NAN, 2.0), " ", f64.tau > 6.28)   // C's names, given to overloads
    var tv_xs = (0..<8).map { bool.random() }           // a body that begins with a type's word, and names no $0 (#549)
    var tv_ys = (0..<3).map { u8.max }
    println(tv_xs.count, " ", tv_xs.typename, " ", tv_ys, " ", tv_top(), " ", $[1, 2].map { 7 })
    let rt_a = 1.over(3)                                // #import <Rational>: rat64 to rat8, and bigrat of BigInts (#542)
    let rt_b = 1n.over(3n)
    println(rt_a + 1.over(6), " ", rt_a * 3, " ", rt_a.f64, " ", rt_a.hex, " ", (-4).over(-8), " ", 1.over(0), " ", rt_a < 1.over(2))
    println(rat32(rt_a), " ", rat8(1, 3) + 1, " ", rat16(100, 3) * rat16(100, 3) * rat16(100, 3), " ", $[rt_a, -rt_a])
    println(rt_b + rt_b, " ", rt_b * 3 - 1, " ", bigrat(rt_a) == rt_b, " ", rat64(rt_b), " ", rt_b.f64, " ", rt_b.hex, " ", 2n.over(4))
    return 0
}

// a number's methods (#542): int32 is i32, and Self the number; written
// after main, which calls them (#543)
extend i64 {
    let nm_twice():i64 { self * 2 }
}
extend int32 {
    let nm_twice():Self { self * 3 }
}
let f64.nm_half():f64 { self / 2.0 }

// a body's one expression, a type's own value (#549)
let tv_top():i64 { i64.max }

// attributes read before they are written (#544)
let tm_v2.at_norm:f64 { self.x * self.x + self.y * self.y }
extend i64 {
    let at_sq:i64 { self * self }
}

// a let parameter's array, walked up to its count, its fifth left (#524)
let fe_sum4(xs:[int32](4)):int64 {
    var t:int64 = 0
    for x in xs { t += x as int64 }
    return t
}
// a JSON.stringify replacer: numbers doubled, the name left out (#516)
let js_doubled(key:cstr, v:const JSON^):JSON? {
    if strcmp(key, "name") == 0 { return none }
    if v^.is(number) { return JSON.number(v^.number * 2.0) }
    return v^.copy()
}
let thrice_va(n:int64, ...):int64 { n * 3 }
let fw_later(n:i64):i64 { n * 2 }
