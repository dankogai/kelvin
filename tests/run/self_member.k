// .x is self.x (#139) in a method, an attribute, a setter and a
// subscript: a member, an attribute, a method, .cstr, an enum's case;
// in an initializer, .x = v is still a designator
struct rect { w: f64; h: f64 }
struct temp { kelvin: f64; log: Array<f64> }
struct grid { w: i64; cells: [i64](4) }
enum maybe { nothing; just: i64 }
extend rect {
    let area:f64 { .w * .h }                                  // members
    let perimeter:f64 { 2.0 * (.w + .h) }
    let scaled(k:f64):rect { return {.w * k, .h * k} }         // in an initializer
    let wider():rect { return {.w = .w + 1.0, .h = .h} }       // after a designator
    let doubled():rect { .scaled(2.0) }                       // a method
    let big:bool { .area > 10.0 }                             // an attribute
    let cstr():cstr { `${.w}x${.h}` }                         // in a template
}
var temp.celsius:f64 {
    get { .kelvin - 273.15 }
    set(v) {
        .kelvin = v + 273.15                                  // set in a setter
        .log += v                                             // a line of its own
    }
}
var grid[](r:i64, c:i64):i64 {
    get { .cells[r * .w + c] }
    set(v) { .cells[r * .w + c] = v }
}
extend maybe {
    let orZero():i64 { .is(just) ? .just : 0 }               // an enum's case
}
let main():i32 {
    let r:rect = {2.0, 3.0}
    println(r.area, " ", r.perimeter, " ", r.scaled(2.0), " ", r.wider(), " ", r.doubled(), " ", r.big)
    var t:temp = {300.0, $[]}
    t.celsius = 100.0
    t.celsius += 1.0
    println(t.celsius, " ", t.log)
    var g:grid = {2}
    g[1, 0] = 5
    g[1, 0] += 1
    println(g[1, 0], " ", g.cells[2], " ", maybe.just(4).orZero(), " ", maybe.nothing.orZero())
    return 0
}
// out: 6.0 10.0 4.0x6.0 3.0x3.0 4.0x6.0 false
// out: 101.0 [100, 101]
// out: 6 6 4 0
// c: return self.w * self.h;
