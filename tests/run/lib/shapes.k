// imported by tests/run/import_kelvin.k (#40), and itself imports a file
// next to it
#import <stdio.h> as C
#import "units.k"

struct square { side: f64 }
struct circle { r: f64 }

let area(s:square):f64 { s.side * s.side }
let area(c:circle):f64 { PI * c.r * c.r }
let describe(s:square) { printf("a square of side %g\n", s.side) }
