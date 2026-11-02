// what only C sees may be a pointer, so a pointer into a temporary inside
// it is held for the call around it (#437), as one a pointer gives
// (#245); the right of && keeps its own, made only where it is evaluated
// out: 2 yz
// out: no side
// out: false
#import <string.h> as C
#import <stdio.h> as C

var calls:int64 = 0
let side():String {
    calls += 1
    return $"side"
}

let main(argc:i32, argv:[cstr]):int32 {
    printf("%zu %s\n", strlen(strchr($"xyz".cstr, 'y')), strchr($"xyz".cstr, 'y'))
    let lengthy = argc > 5 && strlen(side().cstr) > 3
    println(calls == 0 ? "no side" : "side")
    println(lengthy)
    return 0
}
