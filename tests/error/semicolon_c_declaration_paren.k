// error: declarations are written 'var name:type', as in 'var n:size_t'
#import <stddef.h> as C
let main():int32 {
    var x:int64 = 0
    var p:any^ := &x
    size_t n
    (p as int64^)^ = 1
    return 0
}
