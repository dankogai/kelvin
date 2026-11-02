// x.isEmpty (#434) is a property, read with no parentheses
let main():int32 {
    var xs:$[i64] = $[]
    println(xs.isEmpty())
    return 0
}
// error: '.isEmpty' is a property: read it with no parentheses, as 'x.isEmpty'
