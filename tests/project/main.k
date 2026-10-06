// built from tests/project by tests/run.sh: #import <x.k> looks in
// ./modules, then in Kelvin's modules/, and C looks for headers in
// ./modules too (#46)
#import <greet.k>
#import <complex.k>
let main():i32 {
    greet("modules")
    println(abs(complex64(3.0, 4.0)))
    return 0
}
// out: hello, modules
// out: 5.0
