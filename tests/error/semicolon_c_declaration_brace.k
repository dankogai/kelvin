// error: declarations are written 'var name:type', as in 'var fp:FILE^'
#import <stdio.h> as C
let main():i32 {
    if true {
        FILE *fp
    }
    return 0
}
