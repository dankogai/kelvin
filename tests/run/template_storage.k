// template literals without the heap (#39, #44): each value has room for
// its longest text, and a string value shows at most KV_TEMPLATE_STR
// (256) bytes
#import <string.h> as C
struct rec { id: i64; name: cstr }
struct tagged { id: i64; tag: [u8](8) }
let mk():tagged { (tagged){1, ['t', 'a', 'g', 's', 'a', 'n', 'd', 's']} }
let main():i32 {
    var text:[u8](400)
    for i in 0..<399 {
        text[i] = 'a' + (i % 26)
    }
    text[399] = 0
    let s:cstr := &text[0]
    // a longer string is cut, and ends in ...
    let cut:cstr := `<${s}>`
    println(strlen(cut), " ", &cut[strlen(cut) - 8])
    // a nested template keeps its whole text
    println(strlen(`[${`${s}|${s}`}]`))
    // a value that reads the template's earlier text
    var g:cstr := "x"
    var rounds = 0
again:
    g := `${g}y`
    rounds += 1
    if rounds < 300 {
        goto again
    }
    println(strlen(g), " ", &g[strlen(g) - 7])
    // numbers at their longest, also where C converts them to int
    let a:i8 = -128
    let u:u8 = 200
    let low:i128 = i128("-170141183460469231731687303715884105728")
    println(`${a * a} ${-u} ${~u} ${true ? a : a} ${low} ${-2.2250738585072014e-308} ${'A'} ${a < a}`)
    // a struct's string member is cut at 60, as its .cstr is
    let r:rec = {7, s}
    println(strlen(`${r}`))
    // a string of 256 bytes is whole, and one of 257 is cut
    text[256] = 0
    let whole:cstr := `${s}`
    println(strlen(whole), " ", &whole[strlen(whole) - 3])
    text[256] = 'w'
    text[257] = 0
    let longer:cstr := `${s}`
    println(strlen(longer), " ", &longer[strlen(longer) - 6])
    // a byte array is read up to a NUL or its end, never past it, and shown
    // whole up to 256 bytes; a longer one is cut as a string is
    var big:[u8](600)
    for i in 0..<500 {
        big[i] = 'b'
    }
    big[500] = 0
    var mid:[u8](200)
    for i in 0..<199 {
        mid[i] = 'm'
    }
    mid[199] = 0
    var four:[u8](4) = ['a', 'b', 'c', 'd']
    let N = 8
    var eight:[u8](N)
    for i in 0..<N {
        eight[i] = 'e'
    }
    println(strlen(`${big}`), " ", strlen(`${mid}`), " [", `${four}`, "] [", `${eight}`, "] [", `${mk().tag}`, "]")
    // every evaluation of a template writes into its one storage
    var first:cstr := "none"
    var made:cstr := "none"
    var round = 0
next:
    made := `v${round}`
    if round == 0 {
        first := made
    }
    round += 1
    if round < 3 {
        goto next
    }
    println(first, " ", made, " ", first == made)
    return 0
}
// out: 258 pqrs...>
// out: 515
// out: 257 yyy...y
// out: 16384 -200 -201 -128 -170141183460469231731687303715884105728 -2.2250738585072014e-308 65 false
// out: 75
// out: 256 tuv
// out: 256 qrs...
// out: 256 199 [abcd] [eeeeeeee] [tagsands]
// out: v2 v2 true
// c: char _kv_template0[sizeof "<" ">" + KV_TEMPLATE_STR]
// c: KV_TEMPLATE_BYTES(_kv_build
