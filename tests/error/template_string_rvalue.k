// a String that an expression gives in a template (#175), as in a $`...`
// one, would never be freed: bind it first
let main():int32 {
    var n:int64 = 2
    println(`${$"tpl"} ${n}`)
    return 0
}
// error: a String that an expression gives in a template, which nothing would free: bind it to a variable first
