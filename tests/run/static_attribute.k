// a computed attribute of a type (#595): static let T.x:R { ... }, read as
// T.x with no parentheses, and computed at each read, where a stored one,
// static let T.x = v (#133), is one value. So an owner may be one: each
// read gives a new one, the reader's to keep.
struct point { x: int64; y: int64 }
struct name { text: String }
enum item { none; num: int64 }

var reads:int64 = 0

// read before it is written, as a function may be called (#505)
let early():int64 { point.unit.x + point.far.y + name.anonymous.text.count }

extend point {
    static let origin:Self { (point){0, 0} }             // in extend, Self the type
    static let unit:Self {
        reads += 1
        return (point){1, 1}
    }
    static let count:int64 = 2                            // a stored one beside them
    static let of(n:int64):Self { (point){n, n} }        // and a function of the type
    let sum:int64 { .x + .y }                            // an attribute of a value
}
static let point.far:point { (point){1000, point.unit.y + point.count} }   // alone, and by others
static let name.anonymous:name { (name){$"nobody"} }                      // an owner, new at each read
static let item.zero:item { item.num(0) }                                 // of an enum with values

let total(a:point, b:point):int64 { a.sum + b.sum }

let main():int32 {
    let o = point.origin
    println(o.x, " ", point.unit.x, " ", point.unit.sum, " ", point.count, " ", point.of(3).y)
    println(point.far.x, " ", point.far.y, " ", total(point.unit, point.far), " ", point.origin.x + point.unit.y * 2)
    println(reads)                              // each read of point.unit computed it, the two by point.far too
    var n = name.anonymous                      // the reader's own
    n.text += ", yet"
    println(n.text, " ", name.anonymous.text, " ", name.anonymous.text.count)
    let z = item.zero
    println(z.is(num), " ", z.num, " ", early())
    return 0
}
// out: 0 1 2 2 3
// out: 1000 3 1005 2
// out: 7
// out: nobody, yet nobody 6
// out: true 0 10
