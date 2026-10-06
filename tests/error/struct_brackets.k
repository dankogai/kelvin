// a struct or union keeps C's braces: [...] is for an array (#48)
struct point { x: i64; y: i64 }
let main():i32 {
    let p:point = [1, 2]
    return 0
}
// error: '[...]' initializes an array, and this is struct point: a struct or union is initialized with '{...}'
