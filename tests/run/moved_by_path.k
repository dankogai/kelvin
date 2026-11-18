// What is moved out is moved on the path that moved it (#605): the
// branches of an if and the cases of a switch are not both run, so an
// owner one of them moved is whole in the other; after them it is moved
// where any path that goes on moved it; and a block that ends in a return
// goes on nowhere, so if c { return s } leaves s for what follows. One
// list of the names served every path before, and each of these was
// refused, "'s' was moved out and holds nothing now"
let eat(s:String):i64 { s.count as i64 }
let first(c:bool, s:String):String {
    if c { return s }
    return s
}
let either(c:bool, s:String):i64 {
    if c { return eat(s) } else { return eat(s) + 10 }
}
let chain(n:i64, s:String):i64 {
    var got:i64 = 0
    if n == 1 {
        got = eat(s)
    } else if n == 2 {
        got = eat(s) + 20
    } else {
        got = eat(s) + 30
    }
    return got
}
let cases(n:i64, s:String):String {
    switch n {
    case 1: return s
    case 2:
        let k = eat(s)
        return $`two ${k}`
    default: break
    }
    return s
}
let each(n:i64, s:String):i64 {
    var got:i64 = 0
    switch n {
    case 1: got = eat(s)
    case 2: got = eat(s) + 20
    default: got = eat(s) + 30
    }
    return got
}
let bound(o:i64?, s:String):String {
    if let v = o {
        return s
    } else {
        return $`none of ${eat(s)}`
    }
}
let main():int32 {
    println(first(true, $"ab"), " ", first(false, $"cd"), " ", either(true, $"abc"), " ", either(false, $"abc"))
    println(chain(1, $"a"), " ", chain(2, $"a"), " ", chain(3, $"a"))
    println(cases(1, $"one"), " ", cases(2, $"xy"), " ", cases(3, $"rest"))
    println(each(1, $"a"), " ", each(2, $"a"), " ", each(3, $"a"))
    println(bound(5, $"kept"), " ", bound(none, $"abcd"))
    return 0
}
// out: ab cd 3 13
// out: 1 21 31
// out: one two 2 rest
// out: 1 21 31
// out: kept none of 4
