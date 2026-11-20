// a switch holds a break, but a continue needs a loop around it (#649)
let main():int32 {
    switch 1 {
    case 1:
        continue
    default:
        break
    }
    return 0
}
// error: 'continue' goes on to the next turn of a loop, and this is in none
