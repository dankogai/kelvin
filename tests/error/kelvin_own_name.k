// Kelvin.name is the prelude's (#600), and not a name of the program's own
struct P { x: i64 }
let main():int32 {
    let p:Kelvin.P = {1}
    return 0
}
// error: 'Kelvin.P' names nothing: the prelude has no 'P' at its top level (#600)
