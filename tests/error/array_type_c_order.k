// C's T[N] after a type is an error whose hint spells it as [T](N) (#49)
let main():i32 {
    var m:i32^[2][3]^
    return 0
}
// error: an array type is written '[T]', or '[T](N)' with its count (#49): write '[[i32^](3)](2)^' for 'i32^[2][3]^'
