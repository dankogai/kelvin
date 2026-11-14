// an overlay (#551), as Swift's cross-import overlay: where <ovl_len>
// and <ovl_time> are both imported, ./modules/ovl_len+ovl_time.k is
// imported too, with no #import of it written: its type, its alias, its
// function and the operator it gives ovl_len
#import <ovl_len>
#import <ovl_time>
let main():int32 {
    let v:ovl_velocity = ovl_len(100.0) / ovl_time(8.0)
    println(v, " ", v.typename, " ", ovl_kmh(v), " ", sizeof(ovl_speed))
    return 0
}
// out: {mps: 12.5} ovl_speed 45.0 8
