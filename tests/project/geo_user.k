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
    println(geo_area(s), " ", geo_calls, " ", GEO_UNIT)
    return 0
}
// out: (3.0, 4.0) 7.0 4.0 3.0 (6.0, 8.0) 5.0 1
// out: (1.0, 2.0) (2.0, 3.0) true 12.0 0.0 3
// out: 12.0 1 2
