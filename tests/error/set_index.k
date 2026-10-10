// a Set is not indexed (#71)
let main():i32 {
    var s = ${1, 2}
    var y = s[0]
    return 0
}
// error: a Set is not indexed: test an element with '.has(x)', or walk it with 'for x in s'
