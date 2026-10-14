// JSON.stringify(&j, n) (#129): a number as the space, that many spaces a
// level, 0 to 10, as JS's JSON.stringify takes one and as v.pretty(n)
// indents; 0 is compact; a replacer takes one too
#import <JSON>
let keep(key:cstr, v:const JSON^):JSON? { return v^.copy() }
let main():i32 {
    var j = JSON.parse("""
        {"a": [1, 2], "b": true}
        """)
    var four = JSON.stringify(&j, 4)
    println(four)
    var zero = JSON.stringify(&j, 0)
    println(zero)
    var big = JSON.stringify(&j, 99)
    var ten = JSON.stringify(&j, 10)
    println(big == ten, " ", big.count)
    var r = JSON.stringify(&j, keep, 1)
    println(r)
    let n:i64 = 3
    var three = JSON.stringify(&j, n)
    var text = JSON.stringify(&j, "   ")
    println(three == text)
    return 0
}
// out: {
// out:     "a": [
// out:         1,
// out:         2
// out:     ],
// out:     "b": true
// out: }
// out: {"a":[1,2],"b":true}
// out: true 98
// out: {
// out:  "a": [
// out:   1,
// out:   2
// out:  ],
// out:  "b": true
// out: }
// out: true
