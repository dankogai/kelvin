/* kfetch.h - the engine of #import <fetch> (#482, #483): JS's fetch(url,
   init) over HTTP/1.1, in runtime/fetch.c, linked as libkfetch. HTTPS is there
   where libkfetch was built with HAS_SSL=1, through OpenSSL, whose flags
   modules/libkfetch.link gives the program's link. modules/fetch.k wraps
   it. */
#ifndef KFETCH_H
#define KFETCH_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "kelvin_prelude.h"
#include "kIO.h"

/* a request of url, following redirects or not as redirect says, 0 to
   follow up to 20, 1 to give the redirect itself, 2 to make it an error:
   method, "" for GET; the caller's headers as name\0value\0 pairs; the
   body, empty for none; timeout, seconds over the whole request, 0 for
   none, where 60 seconds of silence is the most a wait may be; signal, an
   AbortSignal's id, 0 for none; jar, a CookieJar's, 0 for none, whose
   cookies each request sends and each answer's go into; stream, to give the body as it comes, by
   the IO streamed, its connection open till that is closed. True with the status, its text, the URL it ended
   at, the redirects followed, the headers (read by kfetch_header) and the
   body; false with what went wrong in error */
bool kfetch_request(const uint8_t *url, const uint8_t *method, const kv_bytes *headers_given,
                    const kv_bytes *body_given, int64_t redirect, double timeout, int64_t signal, bool stream, int64_t jar,
                    int64_t *status, kv_string *status_text, kv_string *final_url, int64_t *redirects,
                    kv_bytes *headers, kv_bytes *body, kv_io *streamed, kv_string *error);
/* a body that streams (#488): what went wrong reading the IO streamed gave,
   into message, false where nothing did; the rest of it, appended to out */
bool kfetch_stream_error(const kv_io *io, kv_string *message);
/* a CookieJar (#489), kept for the program's life: a new one's id, 1 up;
   a Set-Cookie as from url, false where it is not taken; the cookies a
   request of url sends, "a=1; b=2"; all of them dropped; how many live */
int64_t kfetch_jar_new(void);
bool kfetch_jar_set(int64_t id, const uint8_t *text, const uint8_t *url);
void kfetch_jar_header(int64_t id, const uint8_t *url, kv_string *out);
void kfetch_jar_clear(int64_t id);
int64_t kfetch_jar_count(int64_t id);
void kfetch_stream_rest(const kv_io *io, kv_bytes *out);
/* an AbortController's state (#487), kept for the program's life: a new
   one's id, 1 up; abort it, with a reason or "" for none, which shuts
   down the socket of a fetch that watches it; whether it was aborted */
int64_t kfetch_abort_new(void);
void kfetch_abort(int64_t id, const uint8_t *reason);
bool kfetch_aborted(int64_t id);
/* header i of what kfetch_get gave, its name lowercased, as JS's
   Headers; false past the last */
bool kfetch_header(const kv_bytes *headers, int64_t i, kv_string *name, kv_string *value);
/* whether libkfetch was built with HTTPS, HAS_SSL=1 */
bool kfetch_has_ssl(void);

#endif
