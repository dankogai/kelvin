// case plain(x): binds nothing where the case carries no value (#119),
// of an enum of the program's as of an Optional's none, where kc ended
// itself (#610)
enum shape { plain; round: f64 }
let main():int32 {
    let s:shape = shape.round(1.0)
    switch s {
    case plain(x): println("plain")
    case round(r): println(r)
    }
    return 0
}
// error: case 'plain' of shape carries no value: nothing to bind, write 'case plain:'
