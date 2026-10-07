// an any^ has no element size to step by (#26, #51)
let main():i32 {
    var v:any^
    v++
    return 0
}
// error: an any^ cannot step: its element has no size
