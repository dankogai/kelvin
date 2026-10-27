// a block defines one type of a name (#390); an inner block may define another
let main():i32 {
    struct pair { a:i64 }
    struct pair { b:i64 }
    return 0
}
// error: 'pair' is defined in this block already
