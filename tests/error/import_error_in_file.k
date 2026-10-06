// an error in an imported file is reported at its place there (#40)
#import "lib/bad.k"
let main():i32 { return 0 }
// error: lib/bad.k:3:
