// a type defined inside a function is written before it in C (#391), where
// its locals are not known: an array member counts by a number
let main():i32 {
    let n = 4
    struct buf { a:[i64](n) }
    return 0
}
// error: a type defined inside a function is written before it in C, where its locals are not known: 'a' of [i64](n) counts by one; write the count
