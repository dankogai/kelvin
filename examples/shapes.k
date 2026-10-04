// Structs and methods: self is a copy of the receiver, every struct has
// derived text (.cstr), and C's <math.h> is a header away.
#import <math.h> as C

let PI = 3.141592653589793

struct point { x:f64; y:f64 }
struct circle { center:point; radius:f64 }
struct rect { corner:point; width:f64; height:f64 }

point.distance(to:point):f64 {
    return hypot(to.x - self.x, to.y - self.y)
}

circle.area():f64 { PI * self.radius * self.radius }
circle.contains(p:point):bool { self.center.distance(p) <= self.radius }
rect.area():f64 { self.width * self.height }

// self is a mutable copy: moving it here leaves the caller's rect alone
rect.moved(dx:f64, dy:f64):rect {
    self.corner.x += dx
    self.corner.y += dy
    return self
}

main():i32 {
    let origin:point = {0, 0}
    let c:circle = {origin, 2}
    let r:rect = {{1, 1}, 3, 4}
    println(c.cstr)
    println(r.cstr, " moved: ", r.moved(2, 0).cstr)
    println("areas ", c.area(), " and ", r.area())
    let p:point = {1, 1.5}
    println(p.cstr, " is ", origin.distance(p), " from the origin, inside: ", c.contains(p))
    return 0
}
// out: {center: {x: 0, y: 0}, radius: 2}
// out: {corner: {x: 1, y: 1}, width: 3, height: 4} moved: {corner: {x: 3, y: 1}, width: 3, height: 4}
// out: areas 12.566370614359172 and 12.0
// out: {x: 1, y: 1.5} is 1.8027756377319946 from the origin, inside: true
