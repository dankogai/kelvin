// alignof takes its type in parentheses (#395), as sizeof(T) does
let main():i32 {
    println(alignof i64)
    return 0
}
// error: alignof takes a type, as C's does: alignof(T); a value's alignment is x.align
