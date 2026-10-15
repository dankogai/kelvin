// #import <name> looks for name.k (#112)
#import <nosuchmodule>
let main():i32 { return 0 }
// error: cannot find <nosuchmodule> (nosuchmodule.kh or nosuchmodule.k) in ./modules or in Kelvin's modules/
