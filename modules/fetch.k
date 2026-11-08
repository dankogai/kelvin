// modules/fetch.k - fetch(url) and fetch(url, init) (#482, #483), JS's fetch:
// the Response of a request of an http or https URL, a GET, or the method,
// headers and body of a RequestInit, or what went wrong, as a
// Result<Response, Error>.
// Written in Kelvin over libkfetch, runtime/fetch.c, an HTTP/1.1 client of
// its own; HTTPS is OpenSSL's where libkfetch was built with HAS_SSL=1.
// Built by kelvinc --lib into fetch.kh and the library that #import <fetch>
// links, with modules/libkfetch.link's flags.
//
//     #import <fetch>
//     var r = fetch("https://example.com/")
//     if let res = r {
//         println(res.status, " ", res.headers["content-type"])
//         println(res.text() ?? $"(not UTF-8)")       // or res.json(), a Result<JSON, Error>
//     } else {
//         println(r.err.message)
//     }
//     var p = fetch("https://example.com/api", (RequestInit){.method = $"POST",
//                   .headers = ${"content-type": $"application/json"}, .body = Bytes("{}")})
#import <kfetch.h> as C
#import <JSON>
#import <IO>

// the engine's functions, by their C names
let kfetch_request(url:cstr, method:cstr, given:const Bytes^, sent:const Bytes^, redirect:i64, timeout:f64, signal:i64, stream:bool, status:i64^, text:String^, final:String^, redirects:i64^, headers:Bytes^, body:Bytes^, streamed:IO^, error:String^):bool
let kfetch_header(headers:const Bytes^, i:i64, name:String^, value:String^):bool
let kfetch_has_ssl():bool
let kfetch_stream_error(io:const IO^, message:String^):bool
let kfetch_stream_rest(io:const IO^, out:Bytes^):()
let kfetch_abort_new():i64
let kfetch_abort(id:i64, reason:cstr):()
let kfetch_aborted(id:i64):bool

// what went wrong: a URL, a method or a header that is not one, the host not
// found, no connection, TLS, an answer that is no HTTP, a redirect where it
// was to be an error, HTTPS where it is not built in, a body that is not text
struct Error {
    message: String
}

// what a redirect does, as JS's init.redirect: follow it, up to 20; give
// the 3xx itself, manual; or make it an Error. C's enum, whose cases are
// words of the program, so each says redirect
enum Redirect { redirectFollow, redirectManual, redirectError }

// a handle to an abort, JS's AbortSignal (#487): a value, so that it is
// copied into a task, as RequestInit's signal, where a fetch watches it;
// id 0, a field left out, is none
struct AbortSignal {
    id: i64
}

extend AbortSignal {
    let aborted:bool { kfetch_aborted(self.id) }   // whether its controller aborted it
}

// JS's AbortController (#487): AbortController() makes one, whose signal a
// fetch on another thread watches, and c.abort() ends that fetch at once, an
// Error, `fetch: aborted` or `fetch: aborted: reason`; a signal aborted
// already fails a fetch before it starts, and stays aborted. Its state is
// kept for the program's life, a few bytes, as a struct has no destructor
struct AbortController {
    signal: AbortSignal
}

let AbortController():AbortController {
    var c:AbortController = {.signal = {.id = kfetch_abort_new()}}
    return c
}

extend AbortController {
    let abort() { kfetch_abort(self.signal.id, "") }
    let abort(reason:cstr) { kfetch_abort(self.signal.id, reason) }
    let abort(reason:const String^) { kfetch_abort(self.signal.id, reason^.cstr) }
}

// a request's method, "" for GET, its headers, sent as written, its body,
// empty for none, and what a redirect does, as JS's RequestInit; a field
// left out of (RequestInit){...} is empty, and its redirect follows; its
// timeout, seconds over the whole request, redirects and all, 0 for none,
// where a wait of 60 seconds with nothing is the most (#486); its signal,
// an AbortController's, which ends it at once when aborted (#487); stream,
// to read the body as it comes, by the Response's stream (#488)
struct RequestInit {
    method: String
    headers: Dictionary<String, String>
    body: Bytes
    redirect: Redirect
    timeout: f64
    signal: AbortSignal
    stream: bool
}

// what a server answered, after the redirects followed: its status and the
// status's text, ok for 200 to 299, the URL it ended at, the headers, names
// lowercased and repeated ones joined by ", ", and the body as sent; or,
// where RequestInit's stream asked, the body as it comes, an IO, closed with
// its connection when the Response's block ends, the body empty (#488)
struct Response {
    status: i64
    statusText: String
    ok: bool
    url: String
    redirected: bool
    headers: Dictionary<String, String>
    body: Bytes
    stream: IO
}

extend Response {
    // what went wrong reading the stream, an abort, the timeout, a body cut
    // short, or none where it ended as it should (#488)
    let streamError:Error? {
        var m = $""
        if !kfetch_stream_error(&self.stream, &m) { return none }
        var e:Error = {.message = m.copy()}
        return e
    }

    // the body as text, or an Error where it is not UTF-8; of a stream,
    // what is left of it, read now, or its Error
    let text():Result<String, Error> {
        var all = self.body.copy()
        kfetch_stream_rest(&self.stream, &all)
        if let e = self.streamError { return err(e.copy()) }
        var s = all.string()
        if let err(at) = s {
            var e:Error = {.message = $`fetch: the body is not UTF-8 at byte ${at}`}
            return err(e)
        }
        return s.ok.copy()
    }

    // the body as JSON, JS's res.json() (#484): or an Error where it is
    // not UTF-8, or not JSON, with JSON.parse's message
    let json():Result<JSON, Error> {
        var t = self.text()
        if let err(e) = t {
            return err(e.copy())
        }
        var j = JSON.parse(&t.ok)
        if j.is(error) {
            var e:Error = {.message = $`fetch: the body is not JSON: ${j.error}`}
            return err(e)
        }
        return j
    }
}

// the Response of a request of url as init says: its method, headers and
// body, and what a redirect does
let fetch(url:cstr, init:const RequestInit^):Result<Response, Error> {
    var given = Bytes()                         // the headers as name\0value\0 pairs
    for k, v in init^.headers {
        given += k.cstr
        given += 0
        given += v.cstr
        given += 0
    }
    var res:Response = {.status = 0}            // filled in place: an IO is moved, never copied
    var redirects:i64 = 0
    var raw = Bytes()
    var why = $""
    if !kfetch_request(url, init^.method.cstr, &given, &init^.body, init^.redirect as i64, init^.timeout, init^.signal.id, init^.stream, &res.status, &res.statusText, &res.url, &redirects, &raw, &res.body, &res.stream, &why) {
        var e:Error = {.message = why.copy()}
        return err(e)
    }
    res.ok = res.status >= 200 && res.status <= 299
    res.redirected = redirects > 0
    var name = $""
    var value = $""
    var i:i64 = 0
    while kfetch_header(&raw, i, &name, &value) {
        if res.headers.has(name) {
            res.headers[name] += ", "
            res.headers[name] += &value
        } else {
            res.headers[name] = value.copy()
        }
        i += 1
    }
    return res
}

// a RequestInit written in the call, moved in: fetch(url, (RequestInit){.method = $"POST"})
let fetch(url:cstr, init:RequestInit):Result<Response, Error> { fetch(url, &init) }
let fetch(url:const String^, init:const RequestInit^):Result<Response, Error> { fetch(url^.cstr, init) }
let fetch(url:const String^, init:RequestInit):Result<Response, Error> { fetch(url^.cstr, &init) }

// the Response of a GET of url, following up to 20 redirects
let fetch(url:cstr):Result<Response, Error> {
    var init:RequestInit = {.method = $"GET"}
    return fetch(url, &init)
}

let fetch(url:const String^):Result<Response, Error> { fetch(url^.cstr) }
