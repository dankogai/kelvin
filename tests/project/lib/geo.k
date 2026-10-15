// built by tests/run.sh with kelvinc --lib into the modules/ of a copy of
// tests/project, as geo.kh and libkgeo.a (#146): every kind of member a
// header declares, and a global, a C prototype and a file-local helper
#import <math.h> as C
let fabs(x:f64):f64                                       // a C function's prototype

struct point { x: f64; y: f64 }
enum shape { dot: point; circle: f64; none }

let origin:point = {0.0, 0.0}                             // a global, extern in the header
var made:i64 = 0

static let twice(x:f64):f64 { x * 2.0 }                   // file-local: not in the header

extend point {
    static let of(x:f64, y:f64):Self { made += 1; return {x, y} }
    let norm1:f64 { fabs(.x) + fabs(.y) }                 // an attribute
    var first:f64 {                                       // one with a setter
        get { .x }
        set(v) { .x = v }
    }
    let [](i:i64):f64 { i == 0 ? .x : .y }                // a subscript
    var [](name:cstr):f64 {
        get { name[0] == 'x' ? .x : .y }
        set(v) { if name[0] == 'x' { .x = v } else { .y = v } }
    }
    let scaled(k:f64):Self { return {twice(.x) * k / 2.0, .y * k} }   // a method, using the helper
    static let +(a:Self, b:Self):Self { return {a.x + b.x, a.y + b.y} }
    static let ==(a:Self, b:Self):bool { a.x == b.x && a.y == b.y }
    let cstr():cstr { `(${.x}, ${.y})` }                  // its text
}
let point.dist(to:point):f64 { hypot(to.x - .x, to.y - .y) }   // alone
let shape.area():f64 {
    switch self {
    case circle(r): return 3.0 * r * r
    default: return 0.0
    }
}
