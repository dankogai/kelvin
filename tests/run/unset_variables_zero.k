// a variable declared with no value is zero (#761): a number and a bool
// 0, a struct, a union, an enum and a fixed array of zeros, an array of
// a count C computes and a v.type of it too, as a pointer is nowhere and
// an owner empty; kelvinc left them unset, as C does
#import <stddef.h> as C
struct point { x:int64, y:int64 }
struct empty { }
enum color { red, green }
union both { i:int64, f:float64 }
let fill():int64 {
    var junk:[int64](8) = [9, 9, 9, 9, 9, 9, 9, 9]
    return junk[7]
}
let read():int64 {
    var x:int64
    var f:float64
    var b:bool
    var p:point
    var c:color
    var u:both
    var a:[int64](8)
    var m:[point](2)
    var e:empty
    var z:size_t
    var n:int64 = 3
    var v:[int64](n)
    var w:v.type
    var rows:[[int64](n)](2)
    var total:int64 = x + p.x + p.y + u.i + a[0] + a[7] + m[1].y + v[2] + w[1] + rows[1][2] + z as int64
    for (var i:int64; i < 3; i += 1) { total += i }
    println(x, " ", f, " ", b, " ", c == red, " ", e.size, " ", total)
    return total
}
let main():int32 {
    fill()
    read()
    static var kept:int64
    kept += 1
    println(kept)
    return 0
}
// out: 0 0.0 false true 0 3
// out: 1
