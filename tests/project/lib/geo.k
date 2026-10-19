// built by tests/run.sh with kelvinc --lib into the modules/ of a copy of
// tests/project, as geo.kh and libkgeo.a (#146): every kind of member a
// header declares, and a global, a C prototype and a file-local helper;
// and C of its own, whose declarations geo.kh has in its #inline C (#199)
#import <math.h> as C
let fabs(x:float64):float64                                       // a C function's prototype

struct point { x: float64; y: float64 }
enum shape { dot: point; circle: float64; none }

let origin:point = {0.0, 0.0}                             // a global, extern in the header
var made:int64 = 0

static let twice(x:float64):float64 { x * 2.0 }                   // file-local: not in the header

#inline C {
#define GEO_UNIT 2                      /* a macro, as it is */
typedef struct { double w, h; } geo_size;
int64_t geo_calls = 0;                  // a global: extern, without its value
static double geo_half(double v) { return v / 2.0; }   /* file-local: not in the header */
double geo_area(geo_size s) {           /* a function: its prototype */
    geo_calls++;
    return geo_half(s.w * s.h) * 2.0;
}
}

extend point {
    static let of(x:float64, y:float64):Self { made += 1; return {x, y} }
    let norm1:float64 { fabs(.x) + fabs(.y) }                 // an attribute
    var first:float64 {                                       // one with a setter
        get { .x }
        set(v) { .x = v }
    }
    let [](i:int64):float64 { i == 0 ? .x : .y }                // a subscript
    var [](name:cstr):float64 {
        get { name[0] == 'x' ? .x : .y }
        set(v) { if name[0] == 'x' { .x = v } else { .y = v } }
    }
    let scaled(k:float64):Self { return {twice(.x) * k / 2.0, .y * k} }   // a method, using the helper
    static let +(a:Self, b:Self):Self { return {a.x + b.x, a.y + b.y} }
    static let ==(a:Self, b:Self):bool { a.x == b.x && a.y == b.y }
    let cstr():cstr { `(${.x}, ${.y})` }                  // its text
}
let point.dist(to:Self):float64 { hypot(to.x - .x, to.y - .y) }   // alone
let shape.area():float64 {
    switch self {
    case circle(r): return 3.0 * r * r
    default: return 0.0
    }
}
