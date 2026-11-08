// fetch(url, init) (#483), JS's RequestInit: a method, normalized as JS's
// fetch does (post is POST, patch stays patch), headers sent as written,
// fetch's own where none are given, a body with its Content-Length; a HEAD
// has no body; a GET with one, a method or a header that is not one, or
// one that fetch sends itself, is an Error. A 303 asks again by GET, as a
// 301 or 302 does a POST, without the body; a 307 or 308 keeps them; another
// origin is not sent the Authorization. redirect is redirectFollow, redirectManual or redirectError
#import <fetch>
let show(r:const Result<Response, Error>^) {
    if let res = r^ {
        var t = res.text() ?? $"(no text)"
        println(res.status, " ", res.redirected, " [", t.trim(), "]")
    } else {
        println(r^.err.message)
    }
}
let main(argc:int32, argv:u8^^):int32 {
    let base:cstr := argv[1]
    var post = fetch(`${base}/method`, (RequestInit){.method = $"POST", .headers = ${"Content-Type": $"text/plain", "X-Custom": $"yes"}, .body = Bytes("hello")})
    show(&post)
    var lower = fetch(`${base}/method`, (RequestInit){.method = $"post", .body = Bytes("x")})
    show(&lower)
    var patch = fetch(`${base}/method`, (RequestInit){.method = $"patch", .body = Bytes("p")})
    show(&patch)
    var put = fetch(`${base}/method`, (RequestInit){.method = $"PUT"})
    show(&put)
    var del = fetch(`${base}/method`, (RequestInit){.method = $"DELETE", .headers = ${"User-Agent": $"mine"}})
    show(&del)
    var head = fetch(`${base}/hello`, (RequestInit){.method = $"HEAD"})
    if let res = head {
        println(res.status, " ", res.body.count, " ", res.headers["content-length"])
    }
    var init:RequestInit = {.method = $"GET", .body = Bytes("no")}
    var bad = fetch(`${base}/method`, &init)
    show(&bad)
    var trace = fetch(`${base}/method`, (RequestInit){.method = $"trace"})
    show(&trace)
    var space = fetch(`${base}/method`, (RequestInit){.method = $"GO ON"})
    show(&space)
    var host = fetch(`${base}/method`, (RequestInit){.headers = ${"Host": $"elsewhere"}})
    show(&host)
    var name = fetch(`${base}/method`, (RequestInit){.headers = ${"a b": $"c"}})
    show(&name)
    var line = fetch(`${base}/method`, (RequestInit){.headers = ${"X-Custom": $"a\r\nX-Evil: 1"}})
    show(&line)
    for code in ([cstr])["/301", "/302", "/303", "/307", "/308"] {
        var r = fetch(`${base}${code}`, (RequestInit){.method = $"POST", .headers = ${"content-type": $"text/plain"}, .body = Bytes("again")})
        print(code, ": ")
        show(&r)
    }
    var put303 = fetch(`${base}/303`, (RequestInit){.method = $"PUT", .body = Bytes("gone")})
    show(&put303)
    var manual = fetch(`${base}/redirect`, (RequestInit){.redirect = redirectManual})
    if let res = manual {
        println(res.status, " ", res.redirected, " ", res.url, " ", res.headers["location"])
    }
    var error = fetch(`${base}/redirect`, (RequestInit){.redirect = redirectError})
    show(&error)
    var same = fetch(`${base}/307`, (RequestInit){.headers = ${"Authorization": $"Bearer t"}})
    show(&same)
    var other = fetch(`${base}/elsewhere`, (RequestInit){.headers = ${"Authorization": $"Bearer t"}})
    if let res = other {
        var t = res.text() ?? $""
        println(res.url.starts("http://localhost:"), " ", t.trim())
    }
    var u = $`${base}/method`
    var w = fetch(&u, (RequestInit){.method = $"OPTIONS"})
    show(&w)
    return 0
}
// out: 200 false [POST|hello|text/plain|5|yes|None|Kelvin-fetch]
// out: 200 false [POST|x|None|1|None|None|Kelvin-fetch]
// out: 200 false [patch|p|None|1|None|None|Kelvin-fetch]
// out: 200 false [PUT||None|0|None|None|Kelvin-fetch]
// out: 200 false [DELETE||None|None|None|None|mine]
// out: 200 0 some("13")
// out: fetch: a GET request has no body
// out: fetch: the method trace is not fetch's to send
// out: fetch: a method is a word of letters, digits and !#$%&'*+-.^_`|~, and this is GO ON
// out: fetch: the header 'Host' is fetch's own to send
// out: fetch: a header's name is a word of letters, digits and !#$%&'*+-.^_`|~, and this is 'a b'
// out: fetch: the header 'X-Custom' has a line break in its value
// out: /301: 200 true [GET||None|None|None|None|Kelvin-fetch]
// out: /302: 200 true [GET||None|None|None|None|Kelvin-fetch]
// out: /303: 200 true [GET||None|None|None|None|Kelvin-fetch]
// out: /307: 200 true [POST|again|text/plain|5|None|None|Kelvin-fetch]
// out: /308: 200 true [POST|again|text/plain|5|None|None|Kelvin-fetch]
// out: 200 true [GET||None|None|None|None|Kelvin-fetch]
// out: 302 false BASE/redirect some("/hello")
// out: fetch: BASE/redirect redirected to /hello, and the redirect was to be an error
// out: 200 true [GET||None|None|None|Bearer t|Kelvin-fetch]
// out: true GET||None|None|None|None|Kelvin-fetch
// out: 200 false [OPTIONS||None|None|None|None|Kelvin-fetch]
