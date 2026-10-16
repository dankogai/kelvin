// a case is at the top of the switch block: no Duff's device (#63)
let main():int32 {
    var n:int32 = 1
    switch n {
    case 1:
        if n > 0 {
    case 2:
            println(2)
        }
    default:
        break
    }
    return 0
}
// error: a case is written at the top of the switch's block, not inside a statement of it
