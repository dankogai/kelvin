// self.x in a function, as .x is (#139), has no self either (#621)
struct point { x: i64; y: i64 }
let getx(p:point):i64 { return self.x }
let main():int32 {
    var p:point = {1, 2}
    println(getx(p))
    return 0
}
// error: 'self' is the value of a method, an attribute or a subscript, and a function has no self
