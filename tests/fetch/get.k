// fetch(url) (#482): a GET and its Response, the status, its text and ok,
// the headers, names lowercased and repeats joined, the body as sent, by
// Content-Length, chunks or the connection's end; text() of what is not
// UTF-8 is an Error; a String's URL, by reference; two fetches at once, by
// async of a function that takes the String moved in
#import <fetch>
let fetched(url:String):Result<Response, Error> { fetch(&url) }   // a String moved in, for async
let get(base:cstr, path:cstr) {
    var r = fetch(`${base}${path}`)
    if let res = r {
        var t = res.text() ?? $"(no text)"
        println(path, ": ", res.status, " ", res.statusText, " ", res.ok, " ", res.redirected, " ", res.url, " ", res.body.count, " [", t.trim(), "]")
    } else {
        println(path, ": ", r.err)
    }
}
let main(argc:int32, argv:u8^^):int32 {
    let base:cstr := argv[1]
    get(base, "/hello")
    get(base, "/query?a=1&b=2#fragment")
    get(base, "/missing")
    get(base, "/chunked")
    get(base, "/close")
    get(base, "/empty")
    get(base, "/echo")
    var b = fetch(`${base}/bytes`)
    if let res = b {
        println(res.body.count, " ", res.body[0], " ", res.headers["content-type"], " ", res.text())
    }
    var h = fetch(`${base}/headers`)
    if let res = h {
        println(res.headers["x-twice"], " ", res.headers["x-mixed-case"], " ", res.headers["X-Twice"])
    }
    var l = fetch(`${base}/latin1`)
    if let res = l {
        println(res.headers["x-name"])
    }
    var u = $`${base}/hello`
    var s = fetch(&u)
    println(s.is(ok), " ", s.ok.url == u)
    var t = async fetched($`${base}/chunked`)   // a String moved into the call's thread
    var m = async fetched($`${base}/missing`)
    var tr = await t
    var mr = await m
    println(tr.ok.body.count, " ", mr.ok.status)
    return 0
}
// out: /hello: 200 OK true false BASE/hello 13 [hello, fetch]
// out: /query?a=1&b=2#fragment: 200 OK true false BASE/query?a=1&b=2 15 [the query came]
// out: /missing: 404 Not Found false false BASE/missing 13 [no such page]
// out: /chunked: 200 OK true false BASE/chunked 21 [chunk one, chunk two]
// out: /close: 200 OK true false BASE/close 14 [until the end]
// out: /empty: 204 No Content true false BASE/empty 0 []
// out: /echo: 200 OK true false BASE/echo 28 [GET /echo|host|Kelvin-fetch]
// out: 3 255 some("application/octet-stream") err({message: "fetch: the body is not UTF-8 at byte 0"})
// out: some("a, b") some("Value Kept") none
// out: some("café")
// out: true true
// out: 21 404
