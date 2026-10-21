// extend T { } (#130), Swift's extension, and attributes: let T.x:R { }
// a computed attribute read as v.x (#131); var T.x:R { get set } one
// with a setter, written as v.x = y on the var that holds v (#132);
// static let T.x = v and static var T.x = v type attributes, read and
// written as T.x (#133); each written outside, with T., or inside extend
struct rect { w: float64; h: float64 }
struct temp { kelvin: float64 }
let rect.area:float64 { .w * .h }                    // outside extend
var temp.celsius:float64 {
    get { .kelvin - 273.15 }
    set(v) { .kelvin = v + 273.15 }
}
static var rect.made:int64 = 0
extend rect {
    let perimeter:float64 { 2.0 * (.w + .h) }        // an attribute
    let scaled(k:float64):Self { (Self){.w * k, .h * k} }   // a method
    let doubled():Self { .scaled(2.0) }              // which calls another
    static let unit:Self = {1.0, 1.0}                     // a type attribute
    static let square(s:float64):Self {                       // a function of the type (#111)
        Self.made += 1
        return {s, s}
    }
    let cstr():cstr { `${.w}x${.h}` }             // its own text (#53)
}
extend temp {
    var fahrenheit:float64 {
        get { .celsius * 9.0 / 5.0 + 32.0 }
        set(v) { .celsius = (v - 32.0) * 5.0 / 9.0 }
    }
}
extend float64 {
    let half:Self { self / 2.0 }                           // a built-in type too
}
let main():int32 {
    let r:rect = {2.0, 3.0}
    println(r.area, " ", r.perimeter, " ", r.scaled(2.0), " ", r.doubled(), " ", r)
    var t:temp = {300.0}
    t.celsius = 100.0
    println(t.kelvin, " ", t.celsius)
    t.celsius += 10.0
    t.fahrenheit = 212.0
    println(t.celsius, " ", t.fahrenheit)
    let s = rect.square(4.0)
    let u = rect.square(1.0)
    println(rect.unit, " ", s.area, " ", rect.made, " ", u)
    rect.made = 0
    let x:float64 = 9.0
    println(rect.made, " ", x.half, " ", rect.unit.area)
    return 0
}
// out: 6.0 10.0 4.0x6.0 4.0x6.0 2.0x3.0
// out: 373.14999999999998 100.0
// out: 100.0 212.0
// out: 1.0x1.0 16.0 2 1.0x1.0
// out: 0 4.5 1.0
// c: temp__set_celsius(&(t), 100.0)
// c: rect__made
