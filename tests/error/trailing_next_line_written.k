// error: a trailing function starts on the line of the call's ')': on the next line, '{' starts a block
#import <stdlib.h> as C
#import <string.h> as C
let main():i32 {
    var names:[u8^](3) = ["kelvin", "celsius", "rankine"]
    qsort(names, 3, sizeof(cstr))
    { (a:const any^, b:const any^):i32 in
        strcmp((a as const cstr^)^, (b as const cstr^)^)
    }
    return 0
}
