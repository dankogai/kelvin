// a := b of two Arrays is no reference's assignment (#755): kelvinc
// built it, a copy of the Array's own pointer, and freed it twice
let main():int32 {
    var a:$[int64] = $[1]
    var b:$[int64] = $[2, 3]
    a := b
    println(a)
    return 0
}
// error: 'a' is a value (Array<i64>): assign it with '=', not ':='
