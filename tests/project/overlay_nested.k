// an overlay's two modules need not be imported by one file (#551):
// <ovl_trip> imports <ovl_time>, and the program <ovl_len>
#import <ovl_trip>
#import <ovl_len>
let main():int32 {
    let v:ovl_speed = ovl_len(72000.0) / ovl_hours(2.0)
    println(v.mps, " ", ovl_kmh(v))
    return 0
}
// out: 10.0 36.0
