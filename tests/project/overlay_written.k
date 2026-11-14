// an overlay written out, #import <ovl_len+ovl_time>, is a module as any
// (#551): it imports its two modules, and is read once, where both are
// imported after it too
#import <ovl_len+ovl_time>
#import <ovl_time>
#import <ovl_len>
let main():int32 {
    println(ovl_len(9.0) / ovl_time(3.0))
    return 0
}
// out: {mps: 3.0}
