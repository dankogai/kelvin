// error: kv_condition_is_not_bool
// fgets returns a pointer: write `while fgets(...) != nullptr { ... }`
#import <stdio.h> as C
let main():int32 {
    var line:[uint8](80);
    while fgets(line, 80, stdin) {
        print(line);
    }
    return 0;
}
