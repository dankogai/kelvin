// a borrow of an owner an expression gives (#157) is held only inside an
// expression that uses it (#187): one kept in a reference would dangle
let main():int32 {
    let p := &$"text"
    return 0
}
// error: a borrow of a String that an expression gives, which nothing would free: bind it to a variable first
