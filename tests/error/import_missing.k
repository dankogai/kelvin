// "x.k" is looked for next to the importing file (#40)
#import "lib/none.k"
let main():i32 { return 0 }
// error: cannot find "lib/none.k" next to the file that imports it
