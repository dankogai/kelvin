// found in ./modules by tests/project/main.k, which tests/run.sh builds
// from tests/project (#46)
#import <greet.h> as C
let greet(name:cstr) {
    println(GREETING, ", ", name)
}
