// async f(x) and await (#312): the call is made on a thread of its own,
// and gives a Task<R> of f's result, or a Task where f has none; its
// arguments are passed as any call's, a value copied and an owner moved
// in; await waits for it and gives the value, once; the end of its block
// waits for a Task never awaited, and frees its value
let fib(n:int64):int64 { n < 2 ? n : fib(n - 1) + fib(n - 2) }
let shout(s:String):String {
    var t = s.copy()
    t.append("!")
    return t
}
let hello(n:int64) { println("hello from a thread of its own, ", n) }
let start(k:int64):Task<int64> { async fib(k) }
let finish(t:Task<int64>):int64 { await t }
let sum(from:int64, to:int64):int64 {
    var s:int64 = 0
    for i in from..<to { s += i }
    return s
}
let maybe(n:int64):int64? { n > 0 ? n : none }
let main():int32 {
    let a = async fib(20)
    let b = async fib(10)
    var name = String("tasks")
    let c = async shout(name)
    let twice:(int64):int64 := { $0 * 2 }
    let d:Task<int64> = async twice(21)
    println(await a, " ", await b, " ", await c, " ", await d)
    let h = async hello(7)
    await h
    println(await async fib(15), " ", finish(start(10)))
    var ts = Array<Task<int64>>()
    for i in 0..<4 { ts.append(async sum(i * 1000, i * 1000 + 1000)) }
    var total:int64 = 0
    for i in 0..<ts.count { total += await ts[i] }
    println(total == sum(0, 4000))
    var r = async fib(1)
    r = async fib(2)
    println(await r)
    let m = async maybe(5)
    if let some(x) = await m { println(x) }
    let never = async shout(String("never awaited"))
    return 0
}
// out: 6765 55 tasks! 42
// out: hello from a thread of its own, 7
// out: 610 55
// out: true
// out: 1
// out: 5
