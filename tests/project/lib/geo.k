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
enum { GEO_UNIT = 2 };                  /* a constant, an enum's: no preprocessor (#296) */
typedef struct { double w, h; } geo_size;
int64_t geo_calls = 0;                  // a global: extern, without its value
struct geo_rect { double w, h; } geo_unit = {1.0, 1.0};     // a type and a variable at once (#200)
static struct geo_cache { int hits; } geo_cache_now;       // the variable the file's own, the type not
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
    inline let swapped():Self { return {.y, .x} }            // inline in extend (#392)
    static let +(a:Self, b:Self):Self { return {a.x + b.x, a.y + b.y} }
    static let ==(a:Self, b:Self):bool { a.x == b.x && a.y == b.y }
    let cstr():cstr { `(${.x}, ${.y})` }                  // its text
    let f64:float64 { .x + .y }                           // point__f64 in C, as point(v:float64) below would be (#575)
    static let unit:Self { made += 1; return {1.0, 1.0} }    // a computed attribute of the type (#595): { get } in geo.kh
}
static let shape.unit:shape { shape.circle(point.unit.x) }   // alone, and by another
let point.dist(to:Self):float64 { hypot(to.x - .x, to.y - .y) }   // alone
let point(v:float64):point { return {v, v} }             // point__f64 in C as the attribute f64 is: _kv_fn_point__f64, to geo.kh's reader too (#575)
inline let point.sum():float64 { .x + .y }               // inline (#392): its body in geo.kh too
inline let halved(v:float64):float64 { v / 2.0 }
let shape.area():float64 {
    switch self {
    case circle(r): return 3.0 * r * r
    default: return 0.0
    }
}
// a function with the name and the types of one of the prelude's, and a
// type with the name of one (#600): each the module's own, by a name of
// its own in C, to geo.kh's reader too; Kelvin.abs and Kelvin.BigInt are
// the prelude's, as geo.kh writes them
let abs(n:int64):int64 { n < 0 ? 0 - n * 2 : n * 2 }
struct Match { score: int64 }
let best(a:Match, b:Match):Match { a.score > b.score ? a : b }
let far(m:Match):Kelvin.BigInt { Kelvin.BigInt(Kelvin.abs(m.score)) * 1000000000000n }
// a function of a type of math's (#601): geo.kh names c64 and writes no
// import of math, which every program has
let turned(z:c64):c64 { z * 1.0.i }
// a variable of the module's own with the name of one of math's
// functions, and a word of an enum of its own with the name of one of
// the prelude's (#604): each the module's, to geo.kh's reader too
var round:int64 = 0
enum reading { nfc, plain }
let turn():int64 { round += 1; return round }
let read():reading { nfc }
