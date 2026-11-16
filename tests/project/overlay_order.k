// an overlay may use another's (#579): <ovl_len+ovl_trip> calls
// <ovl_len+ovl_time>'s operator and its ovl_kmh, and imports it. With
// these imports both stand right after <ovl_len>, the later of each
// one's two, and the one found second was put before the first, where
// it saw none of the other's: "ovl_kmh(...) fits none of its overloads".
// They stand in the order found
#import <ovl_time>
#import <ovl_trip>
#import <ovl_len>
let main():int32 {
    println(ovl_kmh(ovl_len(72000.0), 2.0), " ", ovl_kmh(ovl_len(10.0) / ovl_time(1.0)), " ", (ovl_len(72000.0) / ovl_hours(2.0)).mps)
    return 0
}
// out: 36.0 36.0 10.0
