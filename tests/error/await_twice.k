// await gives a Task's value once (#312): the Task holds nothing afterwards
let one():int64 { 1 }
let main():int32 {
    let t = async one()
    println(await t)
    println(await t)
    return 0
}
// error: 't' was moved out and holds nothing now: assign it anew before using it
