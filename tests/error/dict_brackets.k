// a Dictionary's entries are in braces since #69
let main():i32 {
    var d = $["a": 1]
    return 0
}
// error: a Dictionary's entries are written in braces: ${k: v, ...}, and ${:} for none
