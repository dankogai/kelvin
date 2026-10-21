// error: 'ready' returns a bool, and this is a number: write 'true' or 'false'
let ready():bool { 1 }

let main():int32 {
    println(ready())
    return 0
}
