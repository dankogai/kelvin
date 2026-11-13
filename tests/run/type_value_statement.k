// a statement that begins with a number type's word or bool, then a '.',
// is a value of the type's own (#549): bool.random(), i64.max, f64.pi *
// 2.0, String.fromCodepoints(c), the one expression of a body or of a
// { } given to map; kelvinc took it for C's declaration, 'bool x;'
#import <math>
let top():i64 { i64.max }
let tau():f64 { f64.pi * 2.0 }
let least():f64 { f64.leastNonzeroMagnitude }
let coin():bool { bool.random() }
let word():String { String.fromCodepoints(0x48, 0x69) ?? $"none" }
let big():f64 { f64.tau }
let main():int32 {
    var xs = (0..<8).map { bool.random() }
    var ys = (0..<8).map { i64.random(1...6) }
    var zs = (0..<3).map { f64.pi * 2.0 }
    var ws = (0..<2).map { u8.max }
    var all = true
    for y in ys { if y < 1 || y > 6 { all = false } }
    println(xs.count, " ", ys.count, " ", all, " ", zs, " ", ws, " ", xs.typename)
    let c = coin()
    println(top(), " ", tau(), " ", least() > 0.0, " ", word(), " ", big(), " ", c || !c)
    return 0
}
// out: 8 8 true [6.2831853071795862, 6.2831853071795862, 6.2831853071795862] [255, 255] Array<bool>
// out: 9223372036854775807 6.2831853071795862 true Hi 6.2831853071795862 true
