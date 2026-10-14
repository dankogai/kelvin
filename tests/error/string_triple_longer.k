// a longer delimiter closes with a run as long (#118): """ does not close """"
let main():i32 {
    let s := """"
        holds a """ inside
        """
    return 0
}
// error: unterminated """ string: it ends with 4 quotes, as it began
