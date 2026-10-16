// a """ string ends with as many quotes as it began (#115, #118); the
// opening run is the whole run of quotes
let main():int32 {
    let s := """not closed
    return 0
}
// error: string: it ends with 3 quotes, as it began
