// error: kv_condition_is_not_bool
// fgets returns a pointer: write `while fgets(...) != nullptr { ... }`
#import <stdio.h> as C
let main():i32 {
    var line:u8[80];
    while fgets(line, 80, stdin) {
        print(line);
    }
    return 0;
}
