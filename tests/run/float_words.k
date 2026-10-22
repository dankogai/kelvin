// nan, inf and infinity, in any case, are literals of f64 (#261), as
// $/nan/i and $/inf(inity)?/i, so that what print shows of a NaN or an
// infinity reads back; nan:f32 converts one, as (0.0 / 0.0) as f32
// does. A name the program declares is its own, and nan(...) is C's
// out: nan inf -inf nan inf -inf
// out: f64 nan nan -inf true false
// out: [nan, inf, -inf] {x: inf} -inf inf
// out: 2 nan
struct s { x: float64 }

let main():int32 {
    let a = nan
    let b = inf
    println(a, " ", b, " ", -Infinity, " ", NaN, " ", INF, " ", -infinity)
    println(a.typename, " ", nan:float32, " ", (0.0 / 0.0) as float32, " ", -inf:float32, " ", b > 1e308, " ", a == a)
    println($[nan, inf, -inf], " ", (s){inf}, " ", `${-inf}`, " ", b.cstr)
    var inf = 2
    println(inf, " ", nan)
    return 0
}
