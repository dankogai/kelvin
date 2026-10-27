// a method of a type defined inside a function waits for a number of its own (#391)
let main():i32 {
    struct pair { a:i64 }
    let pair.twice():i64 { return .a * 2 }
    return 0
}
// error: a method of a type defined inside a function is not available yet: define pair at the top level, or write a function that takes it
