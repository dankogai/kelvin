// with one of its two modules imported, an overlay is not read (#551):
// the program's own ovl_speed is the only one, and its own ovl_kmh
#import <ovl_len>
struct ovl_speed { knots: f64 }
let ovl_kmh(v:ovl_speed):f64 { v.knots * 1.852 }
let main():int32 {
    println(ovl_kmh((ovl_speed){10.0}), " ", ovl_len(3.0).m)
    return 0
}
// out: 18.52 3.0
