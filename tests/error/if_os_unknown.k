// an os is macOS, Linux, FreeBSD or Windows (#643), so a misspelt one
// is an error, not a branch quietly not taken
#if os(MacOS)
let x = 1
#endif
let main():int32 { return 0 }
// error: os(MacOS): an os is macOS, Linux, FreeBSD or Windows (#643)
