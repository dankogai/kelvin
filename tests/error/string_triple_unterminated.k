// a """ string ends with """ (#115)
let main():i32 {
    let s := """not closed
    return 0
}
// error: unterminated """ string: it ends with """
