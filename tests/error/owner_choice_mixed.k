// error: this ?: chooses between 's', an owner's place, and a value an expression gives, so one would be freed and the other not: return it, copy the place with .copy(), or choose with if
let main():int32 {
    var s = $"a"
    var c = true
    println(c ? s : $"z")
    return 0
}
