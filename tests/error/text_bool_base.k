// error: a base is for reading an integer from text; bool(...) takes one value
#import <stdlib.h> as C
let main():i32 {
    println(bool(getenv("KELVIN_UNSET"), 2))
    return 0
}
