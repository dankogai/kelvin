// an IO reads bytes and text; a number is read from the text (#88)
#import <IO>
let main():int32 {
    var f = IO.stdin
    var n = f.i64
    return 0
}
// error: an IO reads a byte with '.byte', and text with '.lines', '.read(n)' or '.string': read a number from the text, as i64(line) does (#88)
