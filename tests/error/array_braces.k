// an array kelvinc sees is initialized with [...], not C's braces (#48)
let main():i32 {
    let a:i32[3] = {1, 2, 3}
    return 0
}
// error: an array is initialized with '[...]', not '{...}' (#48)
