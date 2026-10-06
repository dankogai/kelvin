// a Kelvin file is no C header (#40)
#import <complex.k> as C
let main():i32 { return 0 }
// error: a Kelvin file is imported as it is: write '#import <complex.k>' without 'as C'
