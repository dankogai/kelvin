// Structs, methods and attributes in extend blocks (#130, #131): .x is
// self.x (#139) and Self is the type (#140), an attribute is read without
// parentheses, every struct has derived text (.cstr), and C's <math.h> is
// a header away.
#import <math.h> as C

let PI = 3.141592653589793

struct point { x: f64; y: f64 }
struct circle { center: point; radius: f64 }
struct rect { corner: point; width: f64; height: f64 }

extend point {
    let distance(to:Self):f64 {                                   // Self is point
        hypot(to.x - .x, to.y - .y)                               // .x is self.x
    }
}

extend circle {
    let area:f64 { PI * .radius * .radius }                       // an attribute: c.area
    let contains(p:point):bool { .center.distance(p) <= .radius }
}

extend rect {
    let area:f64 { .width * .height }
    // self is a let (#138): a copy moves, and the caller's rect stays
    let moved(dx:f64, dy:f64):Self {
        var r:Self = self
        r.corner.x += dx
        r.corner.y += dy
        return r
    }
}

let main():i32 {
    let origin:point = {0, 0}
    let c:circle = {origin, 2}
    let r:rect = {{1, 1}, 3, 4}
    println(c.cstr)
    println(r.cstr, " moved: ", r.moved(2, 0).cstr)
    println("areas ", c.area, " and ", r.area)
    let p:point = {1, 1.5}
    println(p.cstr, " is ", origin.distance(p), " from the origin, inside: ", c.contains(p))
    return 0
}
// out: {center: {x: 0, y: 0}, radius: 2}
// out: {corner: {x: 1, y: 1}, width: 3, height: 4} moved: {corner: {x: 3, y: 1}, width: 3, height: 4}
// out: areas 12.566370614359172 and 12.0
// out: {x: 1, y: 1.5} is 1.8027756377319946 from the origin, inside: true
