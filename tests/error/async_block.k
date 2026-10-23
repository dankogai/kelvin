// async takes a call, not a block (#312): a block would take the names
// around it, which Kelvin does not enclose
let main():int32 {
    let t = async { 1 }
    return 0
}
// error: 'async' takes a call, as in 'async f(x)', which passes the function what it needs: a block would take the names around it, which Kelvin does not enclose
