// error: '$0' is a value its Array, Dictionary, Optional or Result still owns: return a copy, '$0.copy()'
let main():int32 {
    var names = $[$"a"]
    var same = names.map { $0 }
    return 0
}
