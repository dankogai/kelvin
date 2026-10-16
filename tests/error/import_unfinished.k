// an unfinished block at the end of an imported file is an error there (#40)
#import "lib/unfinished.k"
let main():int32 { return one() }
// error: lib/unfinished.k:2:15: error: unterminated block
