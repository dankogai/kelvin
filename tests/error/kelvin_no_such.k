// Kelvin.name is what the prelude declares at its top level (#600), and
// the prelude has no such name
let main():int32 {
    println(Kelvin.nothing(3))
    return 0
}
// error: 'Kelvin.nothing' names nothing: the prelude has no 'nothing' at its top level (#600)
