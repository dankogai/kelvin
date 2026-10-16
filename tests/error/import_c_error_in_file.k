// so is a C error in an imported file (#40)
#import "lib/bad_c.k"
let main():int32 { return 0 }
// error: lib/bad_c.k:4:
