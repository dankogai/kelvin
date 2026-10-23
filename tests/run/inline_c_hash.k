// a '#' in #inline C's strings, characters and comments is as written
// (#296): only one that begins a line of its code is the preprocessor's
#inline C {
static const char *h = "#define no";   /* #include in a comment */
// #if in a line comment
static char c = '#';
}
let main():int32 {
    println(h, " ", c == 35)
    return 0
}
// out: #define no true
