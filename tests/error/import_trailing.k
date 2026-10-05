// an import takes nothing after the file's name (#40)
#import "lib/bad.k" x
main():i32 { return 0 }
// error: unexpected text after '#import "lib/bad.k"'
