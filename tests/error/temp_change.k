// a change to an owner an expression gives would be lost with it (#187)
let rows():$[int64] { var r = $[1, 2]; return r }
let main():int32 {
    rows().append(3)
    return 0
}
// error: '.append' changes an Array, and this one an expression gives would be lost: bind it to a variable first
