// a continue in no loop (#649)
let main():int32 {
    if true { continue }
    return 0
}
// error: 'continue' goes on to the next turn of a loop, and this is in none
