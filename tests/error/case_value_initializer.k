// {.c = v} of an enum with values holds the case's type (#411)
enum shape { none; circle: float64 }
let main():int32 {
    var s:shape = {.circle = $"r"}
    println(s)
    return 0
}
// error: case 'circle' of shape holds an f64, and this is String
