// a struct, union or enum defined inside a struct or a union (#389),
// Swift's: its bare name inside the one around it and that one's members,
// a path outside, shape.size; point__size in C, written before it
struct shape {
    enum kind { round; sides: i64 }
    struct size {
        struct unit { n:i64 }
        w:f64, h:f64
    }
    union bits { i:i32, f:f32 }
    enum shade { light, dark }
    k:kind
    s:size
    b:bits
    z:shade
}
struct other { struct size { n:i64 }, z:size }
let main():i32 {
    let a:shape = {shape.kind.sides(4), {2.0, 3.0}, {.i = 7}, dark}
    var s:shape.size = {1.0, 1.5}
    let o:other = {{7}}
    println(a, " ", s, " ", o)
    println(s.typename, " ", a.k.typename, " ", o.z.typename, " ", a.b.typename)
    let u:shape.size.unit = {5}
    var us = Array<shape.size.unit>()
    us.append(u)
    let maybe:shape.size.unit? = u
    println(u.typename, " ", us, " ", us.typename, " ", maybe, " ", sizeof(shape.size))
    let c = shape.kind.round
    println(c, " ", c.typename, " ", c == shape.kind.round)
    return 0
}
// out: {k: sides(4), s: {w: 2.0, h: 3.0}, b: <union shape.bits>, z: 1} {w: 1.0, h: 1.5} {z: {n: 7}}
// out: shape.size shape.kind other.size shape.bits
// out: shape.size.unit [{n: 5}] Array<shape.size.unit> some({n: 5}) 16
// out: round shape.kind true
// c: struct shape__size
// c: union shape__bits
// c: struct shape__size__unit
