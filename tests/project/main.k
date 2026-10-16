// built from tests/project by tests/run.sh: #import <x.k> looks in
// ./modules, then in Kelvin's modules/, and C looks for headers in
// ./modules too (#46)
#import <greet.k>
#import <math>
#import <shout>                 // shout.kh, and libkshout.a beside it (#143)
let main():int32 {
    greet("modules")
    println(abs(c64(3.0, 4.0)))
    shout("modules")
    return 0
}
// out: hello, modules
// out: 5.0
// out: modules!
