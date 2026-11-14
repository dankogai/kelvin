// an overlay is read after the later of its two modules, whichever the
// program imports first (#551): ovl_len+ovl_time.k with <ovl_time> first
#import <ovl_time>
#import <ovl_len>
let main():int32 {
    println(ovl_kmh(ovl_len(50.0) / ovl_time(2.0)))
    return 0
}
// out: 90.0
