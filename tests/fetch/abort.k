// an abort by hand (#487), JS's AbortController: its signal, a value, is
// copied into a fetch on another thread, and abort() ends that fetch at
// once, while it waits for the answer or reads a body that trickles in, an
// Error, `fetch: aborted`, or with abort(reason) the reason; a signal
// aborted already fails a fetch before it starts, and stays aborted; an
// abort after a fetch is done changes nothing
#import <fetch>
#import <OS>
let get(url:String, signal:AbortSignal):Result<Response, Error> { fetch(&url, (RequestInit){.signal = signal}) }
// the seconds a fetch took, from the abort, rounded to a tenth: at once is 0.0
let waited(since:f64):f64 { f64(i64((OS.time - since) * 10.0)) / 10.0 }
let main(argc:int32, argv:u8^^):int32 {
    let base:cstr := argv[1]
    var before = AbortController()
    println(before.signal.aborted)
    before.abort()
    var r = fetch(`${base}/hello`, (RequestInit){.signal = before.signal})
    println(r.err.message, " ", before.signal.aborted)
    var slow = AbortController()
    var t = async get($`${base}/slow`, slow.signal)        // an answer a second late
    OS.sleep(0.25)
    let at = OS.time
    slow.abort("user quit")
    var s = await t
    println(s.err.message, " ", waited(at))
    var trickle = AbortController()
    var u = async get($`${base}/trickle`, trickle.signal)  // a byte every 0.2 seconds
    OS.sleep(0.5)
    let at2 = OS.time
    trickle.abort()
    var v = await u
    println(v.err.message, " ", waited(at2))
    var blackhole = AbortController()                         // a connect that waits: 10.255.255.1 answers no one
    var w = async get($"http://10.255.255.1/", blackhole.signal)
    OS.sleep(0.25)
    let at3 = OS.time
    blackhole.abort($"gave up")
    var x = await w
    println(x.err.message.starts("fetch: aborted: gave up") || x.err.message.starts("fetch: cannot connect"), " ", waited(at3) < 0.5)
    var done = AbortController()
    var d = fetch(`${base}/hello`, (RequestInit){.signal = done.signal})
    done.abort("too late")
    done.abort("second")
    println(d.ok.status, " ", done.signal.aborted)
    var again = fetch(`${base}/hello`, (RequestInit){.signal = done.signal})
    println(again.err.message)
    var none:RequestInit = {}
    println(none.signal.aborted, " ", fetch(`${base}/hello`, &none).ok.status)
    return 0
}
// out: false
// out: fetch: aborted true
// out: fetch: aborted: user quit 0.0
// out: fetch: aborted 0.0
// out: true true
// out: 200 true
// out: fetch: aborted: too late
// out: false 200
