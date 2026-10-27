// a type defined inside a function (#391) is known to the end of its block
let main():i32 {
    if true {
        struct pair { a:i64 }
    }
    var p:pair = {1}
    return 0
}
// error: 'pair' is defined in a block that has ended: a type defined inside a function is known to the end of its block
