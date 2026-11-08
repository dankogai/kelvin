// a body that streams (#488): RequestInit's stream, and fetch returns at the
// headers, res.body empty, the body read as it comes from res.stream, an IO,
// by its length, its chunks or the connection's end; closed with its
// connection when the Response's block ends, read or not. res.text() reads
// what is left. A read that fails, by an abort, the timeout or a body cut
// short, ends the stream, and res.streamError says why
#import <fetch>
#import <IO>
#import <OS>
let later(c:AbortController) {
    OS.sleep(0.3)
    c.abort("mid-stream")
}
let main(argc:int32, argv:u8^^):int32 {
    let base:cstr := argv[1]
    var t = fetch(`${base}/trickle`, (RequestInit){.stream = true})
    if let res = t {
        print(res.status, " ", res.body.count, ":")
        for chunk in res.stream.read(4) {
            print(" ", chunk.count)
        }
        println(" ", res.stream.eof, " ", res.streamError)
    }
    var l = fetch(`${base}/lines`, (RequestInit){.stream = true})
    if let res = l {
        for r in res.stream.lines {
            if let line = r { print(line, "|") }
        }
        println(" ", res.streamError)
    }
    var h = fetch(`${base}/hello`, (RequestInit){.stream = true})
    if let res = h {
        for first in res.stream.read(6) {       // the first 6 bytes alone
            print(first.count, " ")
            break
        }
        println(res.text())                        // the rest
    }
    var c = fetch(`${base}/close`, (RequestInit){.stream = true})
    if let res = c {
        println(res.text())
    }
    var r = fetch(`${base}/redirect`, (RequestInit){.stream = true})
    if let res = r {
        println(res.redirected, " ", res.text())
    }
    var cut = fetch(`${base}/cut`, (RequestInit){.stream = true})
    if let res = cut {
        var n = 0
        for chunk in res.stream.read(100) { n += chunk.count }
        println(n, " ", res.streamError)
    }
    var slow = fetch(`${base}/trickle`, (RequestInit){.stream = true, .timeout = 0.5})
    if let res = slow {
        var n = 0
        for chunk in res.stream.read(1) { n += chunk.count }
        println(n < 10, " ", res.streamError)
    }
    var ctl = AbortController()
    var a = fetch(`${base}/trickle`, (RequestInit){.stream = true, .signal = ctl.signal})
    if let res = a {
        var job = async later(ctl)
        var n = 0
        for chunk in res.stream.read(1) { n += chunk.count }
        await job
        println(n < 10, " ", res.streamError, " ", res.text())
    }
    var left = fetch(`${base}/trickle`, (RequestInit){.stream = true})   // dropped unread: its block closes it
    println(left.ok.status)
    var head = fetch(`${base}/hello`, (RequestInit){.stream = true, .method = $"HEAD"})
    if let res = head {
        var n = 0
        for chunk in res.stream.read(10) { n += chunk.count }
        println(n, " ", res.stream.eof)
    }
    var plain = fetch(`${base}/hello`)
    println(plain.ok.body.count, " ", plain.ok.streamError)
    return 0
}
// out: 200 0: 4 4 2 true none
// out: one|two|three| none
// out: 6 ok(" fetch\n")
// out: ok("until the end\n")
// out: true ok("hello, fetch\n")
// out: 4 some({message: "fetch: 127.0.0.1 closed the connection before the body's end, 6 bytes short"})
// out: true some({message: "fetch: the timeout of 0.5 seconds passed"})
// out: true some({message: "fetch: aborted: mid-stream"}) err({message: "fetch: aborted: mid-stream"})
// out: 200
// out: 0 true
// out: 13 none
