// alignof takes a type, as C's does (#395): a value's is x.align
let main():i32 {
    let x = 3
    println(alignof(x))
    return 0
}
// error: alignof takes a type, as C's does: alignof(T); a value's alignment is x.align
