// error: declarations are written 'var name:type', as in 'var n:size_t'
#import <stddef.h> as C
main():i32 {
    var x:i64 = 0
    var p:any^ := &x
    size_t n
    (p as i64^)^ = 1
    return 0
}
