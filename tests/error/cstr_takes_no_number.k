// a cstr is text or nowhere: a number is none (#52, #741)
let main():int32 {
    let s:cstr := 5
    return 0
}
// error: 's' is a cstr, and this is a number
