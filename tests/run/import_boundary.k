let VERSION = 3
#import "lib/late.k"
#import "lib/sub/wrap.k"
#import "lib/../lib/late.k"
#import "import_boundary.k"
let main():i32 {
    println(VERSION, " ", LATE, " ", twice_late(2), " ", add3(2, 3, 4))
    return 0
}
// Kelvin files on both sides of an import (#40): a declaration ends where
// a file ends, whatever the lines' numbers; a C header that an imported
// file imports is found next to it; a file comes in once, also by another
// path or when it is the main file.
// out: 3 4 4 9
