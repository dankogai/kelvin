// .cooked is self.cooked (#139), and no word of the enum the value is
// of: in a function there is no self. kc ended with an index out of
// range here, and says what kelvinc says (#602)
enum Color { raw, cooked }
let main():int32 {
    let n:Color = .cooked
    println(n as i64)
    return 0
}
// error: '.cooked' is self.cooked in a method, an attribute or a subscript, and a function has no self
