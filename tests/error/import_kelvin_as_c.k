// a Kelvin file is no C header (#40)
#import <lib/complex.k> as C
main():i32 { return 0 }
// error: a Kelvin file is imported as it is: write '#import <lib/complex.k>' without 'as C'
