// a 123n literal is the prelude's BigInt (#508), which a type of the
// program named BigInt hides
struct BigInt { digits: i64 }
let main():int32 {
    let x = 5n
    return 0
}
// error: a 123n literal is the prelude's BigInt, which a type of this program named BigInt hides: rename that type (#508)
