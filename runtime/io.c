/* io.c - IO (#82): stdio as an owner. A kv_io holds a FILE *, which its
   block closes when it owns it (a file it opened) and flushes when it
   does not (stdin, stdout, stderr). Opening and reading whole give errno
   as the err of a Result; reading in chunks and lines are walked by for. */
#include "kelvin_prelude.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void kv_io_fail(const char *what) {
    fflush(stdout);
    fprintf(stderr, "kelvin: %s\n", what);
    abort();
}

int kv_io_open(kv_io *out, const void *path, const void *mode) {
    FILE *fp = fopen((const char *)path, (const char *)mode);
    if (!fp)
        return errno ? errno : EIO;
    out->fp = fp;
    out->owned = true;
    return 0;
}

kv_io *kv_io_std(int which) {
    static kv_io streams[3];
    if (!streams[0].fp) {
        streams[0].fp = stdin;
        streams[1].fp = stdout;
        streams[2].fp = stderr;
    }
    return &streams[which < 0 || which > 2 ? 0 : which];
}

void kv_io_free(kv_io *f) {
    if (f->fp) {
        if (f->owned)
            fclose((FILE *)f->fp);
        else
            fflush((FILE *)f->fp);
    }
    f->fp = NULL;
    f->owned = false;
}

kv_io kv_io_take(kv_io *f) {
    kv_io v = *f;
    f->fp = NULL;
    f->owned = false;
    return v;
}

kv_io kv_io_copy(const kv_io *f) {
    (void)f;
    kv_io_fail("an IO is not copied: borrow it with '&f', or pass it on");
    return (kv_io){0};
}

void kv_io_discard(kv_io v) { kv_io_free(&v); }

void kv_io_close(kv_io *f) { kv_io_free(f); }

void kv_io_flush(kv_io *f) {
    if (f->fp)
        fflush((FILE *)f->fp);
}

static FILE *open_fp(const kv_io *f, const char *what) {
    if (!f->fp)
        kv_io_fail(what);
    return (FILE *)f->fp;
}

/* the FILE for print and println (#83) */
void *kv_io_fp(kv_io *f) { return open_fp(f, "printing to a closed IO"); }

/* the rest of the file, or errno: of a stream that cannot be read, such
   as a directory, what ferror reports */
int kv_io_read_all(kv_io *f, kv_bytes *out) {
    if (!f->fp)
        return EBADF;
    FILE *fp = (FILE *)f->fp;
    kv_bytes b = kv_bytes_new();
    uint8_t buf[4096];
    size_t n;
    errno = 0;
    while ((n = fread(buf, 1, sizeof buf, fp)) > 0)
        kv_bytes_append(&b, buf, n);
    if (ferror(fp)) {
        int e = errno ? errno : EIO;
        clearerr(fp);
        kv_bytes_free(&b);
        return e;
    }
    *out = b;
    return 0;
}

/* the rest of the file as a String, or errno; EILSEQ when it is not UTF-8 */
int kv_io_read_string(kv_io *f, kv_string *out) {
    kv_bytes b;
    int e = kv_io_read_all(f, &b);
    if (e)
        return e;
    size_t count;
    if (!kv_utf8_valid(b.at, b.count, &count)) {
        kv_bytes_free(&b);
        return EILSEQ;
    }
    out->b = b;
    out->count = count;
    return 0;
}

/* the next n bytes at most into buf, which the loop owns; false at the end */
bool kv_io_read_chunk(kv_io *f, size_t n, kv_bytes *buf) {
    FILE *fp = open_fp(f, "reading a closed IO");
    kv_bytes_clear(buf);
    uint8_t tmp[4096];
    while (buf->count < n) {
        size_t want = n - buf->count;
        size_t got = fread(tmp, 1, want < sizeof tmp ? want : sizeof tmp, fp);
        if (!got)
            break;
        kv_bytes_append(buf, tmp, got);
    }
    return buf->count > 0;
}

/* the next line, without its newline, into line, which the loop owns;
   false at the end; a line that is not UTF-8 aborts, as a String does */
bool kv_io_read_line(kv_io *f, kv_string *line) {
    FILE *fp = open_fp(f, "reading a closed IO");
    kv_bytes b = kv_bytes_new();
    int c;
    bool any = false;
    while ((c = fgetc(fp)) != EOF) {
        any = true;
        if (c == '\n')
            break;
        kv_bytes_push(&b, (uint8_t)c);
    }
    if (!any) {
        kv_bytes_free(&b);
        return false;
    }
    size_t count;
    if (!kv_utf8_valid(b.at, b.count, &count))
        kv_io_fail("a line read by .lines is not UTF-8: read .bytes, or walk .read(n)");
    kv_string_free(line);
    line->b = b;
    line->count = count;
    return true;
}

void kv_io_write_text(kv_io *f, const void *s) {
    FILE *fp = open_fp(f, "writing a closed IO");
    fputs((const char *)s, fp);
}

void kv_io_write_bytes(kv_io *f, const kv_bytes *b) {
    FILE *fp = open_fp(f, "writing a closed IO");
    if (b->count)
        fwrite(b->at, 1, b->count, fp);
}

void kv_io_write_string(kv_io *f, const kv_string *s) { kv_io_write_bytes(f, &s->b); }

void kv_io_write_owned_bytes(kv_io *f, kv_bytes b) {
    kv_io_write_bytes(f, &b);
    kv_bytes_free(&b);
}

void kv_io_write_owned_string(kv_io *f, kv_string s) {
    kv_io_write_bytes(f, &s.b);
    kv_string_free(&s);
}
