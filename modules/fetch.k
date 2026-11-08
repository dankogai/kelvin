// modules/fetch.k - fetch(url) (#482), JS's fetch as a GET: the Response of
// an http or https URL, or what went wrong, as a Result<Response, Error>.
// Written in Kelvin over libkfetch, runtime/fetch.c, an HTTP/1.1 client of
// its own; HTTPS is OpenSSL's where libkfetch was built with HAS_SSL=1.
// Built by kelvinc --lib into fetch.kh and the library that #import <fetch>
// links, with modules/libkfetch.link's flags.
//
//     #import <fetch>
//     var r = fetch("https://example.com/")
//     if let res = r {
//         println(res.status, " ", res.headers["content-type"])
//         println(res.text() ?? $"(not UTF-8)")
//     } else {
//         println(r.err.message)
//     }
#import <kfetch.h> as C

// the engine's functions, by their C names
let kfetch_get(url:cstr, status:i64^, text:String^, final:String^, redirects:i64^, headers:Bytes^, body:Bytes^, error:String^):bool
let kfetch_header(headers:const Bytes^, i:i64, name:String^, value:String^):bool
let kfetch_has_ssl():bool

// what went wrong: the host not found, no connection, TLS, an answer that
// is no HTTP, HTTPS where it is not built in, a body that is not text
struct Error {
    message: String
}

// what a server answered, after the redirects followed: its status and the
// status's text, ok for 200 to 299, the URL it ended at, the headers, names
// lowercased and repeated ones joined by ", ", and the body as sent
struct Response {
    status: i64
    statusText: String
    ok: bool
    url: String
    redirected: bool
    headers: Dictionary<String, String>
    body: Bytes
}

extend Response {
    // the body as text, or an Error where it is not UTF-8
    let text():Result<String, Error> {
        var s = self.body.string()
        if let err(at) = s {
            var e:Error = {.message = $`fetch: the body is not UTF-8 at byte ${at}`}
            return err(e)
        }
        return s.ok.copy()
    }
}

// the Response of a GET of url, following up to 20 redirects
let fetch(url:cstr):Result<Response, Error> {
    var status:i64 = 0
    var statusText = $""
    var final = $""
    var redirects:i64 = 0
    var raw = Bytes()
    var body = Bytes()
    var why = $""
    if !kfetch_get(url, &status, &statusText, &final, &redirects, &raw, &body, &why) {
        var e:Error = {.message = why.copy()}
        return err(e)
    }
    var headers = Dictionary<String, String>()
    var name = $""
    var value = $""
    var i:i64 = 0
    while kfetch_header(&raw, i, &name, &value) {
        if headers.has(name) {
            headers[name] += ", "
            headers[name] += &value
        } else {
            headers[name] = value.copy()
        }
        i += 1
    }
    var res:Response = {.status = status, .statusText = statusText.copy(), .ok = status >= 200 && status <= 299,
                        .url = final.copy(), .redirected = redirects > 0, .headers = headers.copy(), .body = body.copy()}
    return res
}

let fetch(url:const String^):Result<Response, Error> { fetch(url^.cstr) }
