// error: a trailing function starts on the line of the call's ')': on the next line, '{' starts a block
#import <stdlib.h> as C
#import <string.h> as C
let main():int32 {
    var names:[uint8^](3) = ["kelvin", "celsius", "rankine"]
    qsort(names, 3, sizeof(cstr))
    { (a:const any^, b:const any^):int32 in
        strcmp((a as const cstr^)^, (b as const cstr^)^)
    }
    return 0
}
