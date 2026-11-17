// uses the module geo, built by tests/run.sh from lib/geo.k with
// kelvinc --lib: geo.kh brings in its declarations, and libkgeo.a is
// linked by the import (#146)
#import <geo>
let main():int32 {
    var p = point.of(3.0, 4.0)
    println(p, " ", p.norm1, " ", p[1], " ", p["x"], " ", p.scaled(2.0), " ", p.dist(origin), " ", made)
    p.first = 1.0
    p["y"] = 2.0
    let q = p + point.of(1.0, 1.0)
    println(p, " ", q, " ", q == point.of(2.0, 3.0), " ", shape.circle(2.0).area(), " ", shape.none.area(), " ", made)
    let s:geo_size = {3.0, 4.0}                  // the module's #inline C, by geo.kh (#199)
    let c:struct geo_cache = {0}
    println(geo_area(s), " ", geo_calls, " ", GEO_UNIT, " ", geo_unit.h, " ", c.hits)
    println(q.sum(), " ", halved(q.sum()), " ", q.swapped())   // inline, from geo.kh's bodies (#392)
    println(point(2.5), " ", point(2.5).f64)     // a function named in C as a member is (#575)
    println(point.unit, " ", made, " ", shape.unit.area(), " ", made)   // computed attributes of the types, each read a call (#595)
    let m:Match = {0 - 3}                        // the module's own abs and Match, beside the prelude's (#600)
    println(abs(-3), " ", Kelvin.abs(-3), " ", best(m, (Match){7}).score, " ", far(m), " ", m.typename)
    return 0
}
// out: (3.0, 4.0) 7.0 4.0 3.0 (6.0, 8.0) 5.0 1
// out: (1.0, 2.0) (2.0, 3.0) true 12.0 0.0 3
// out: 12.0 1 2 1.0 0
// out: 5.0 2.5 (3.0, 2.0)
// out: (2.5, 2.5) 5.0
// out: (1.0, 1.0) 4 3.0 5
// out: 6 3 7 3000000000000n Match
