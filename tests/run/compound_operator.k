// x op= y that a type defines (#518): static let +=(a:Self^, b:U), or let
// +=(a:T^, b:U) at the top level, called with &x and y, changes x in
// place; where a type defines none, x op= y is x = x op y (#42)
struct Acc {
    total: i64
    calls: i64
}
extend Acc {
    static let +(a:Self, b:i64):Self { (Self){a.total + b, a.calls} }
    static let *(a:Self, b:i64):Self { (Self){a.total * b, a.calls} }
    static let +=(a:Self^, b:i64) {
        a^.total += b
        a^.calls += 1
    }
    static let +=(a:Self^, b:Self) {
        a^.total += b.total
        a^.calls += 1
    }
}
let -=(a:Acc^, b:i64) {
    a^.total -= b
    a^.calls += 1
}
struct Pair {
    left: Acc
    right: Acc
}
let main():int32 {
    var x:Acc = {0, 0}
    x += 5
    x += 7
    x -= 2
    x *= 3                                // no *=: x = x * 3, which keeps calls
    let y = x + 100
    x += y
    println(x.total, " ", x.calls, " ", y.total)
    var xs:[Acc](2) = [{1, 0}, {2, 0}]
    xs[1] += 10
    var p:Acc^ := &xs[0]
    p^ += 3
    var pair:Pair = {{0, 0}, {0, 0}}
    pair.right += 4
    pair.right += pair.right
    println(xs[0].total, " ", xs[1].total, " ", xs[1].calls, " ", pair.right.total, " ", pair.right.calls)
    return 0
}
// out: 160 4 130
// out: 4 12 1 8 2
