// a struct or union keeps C's braces: [...] is for an array (#48)
struct point { x: int64; y: int64 }
let main():int32 {
    let p:point = [1, 2]
    return 0
}
// error: '[...]' initializes an array, and this is struct point: a struct or union is initialized with '{...}'
