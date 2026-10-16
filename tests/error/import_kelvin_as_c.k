// a Kelvin file is no C header (#40)
#import <math> as C
let main():int32 { return 0 }
// error: a Kelvin file is imported as it is: write '#import <math>' without 'as C'
