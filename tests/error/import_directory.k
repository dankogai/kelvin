// a directory is no Kelvin file, though its name ends in .k (#40)
#import "lib/folder.k"
main():i32 { return 0 }
// error: cannot find "lib/folder.k" next to the file that imports it
