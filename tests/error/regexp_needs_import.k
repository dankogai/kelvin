// a $/.../ literal (#157) is RegExp.compile("...", "...") of <RegExp>, so a
// file that has not imported it cannot write one
let main():int32 {
    let re = $/a+/
    return 0
}
// error: a $/.../ literal is a RegExp, which needs #import <RegExp>
