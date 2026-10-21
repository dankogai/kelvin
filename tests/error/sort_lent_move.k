// error: 'a' is a value its Array, Dictionary, Optional or Result still owns: pass a borrow, '&a', or a copy
let keep(s:String):bool { return s.count > 0 }

let main():int32 {
    var xs:$[String] = $[]
    xs.sort { a, b in keep(a) }
    return 0
}
