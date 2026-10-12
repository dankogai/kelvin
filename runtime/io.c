/* io.c - IO (#82): stdio as an owner. A kv_io holds a FILE *, which its
   block closes when it owns it (a file it opened) and flushes when it
   does not (stdin, stdout, stderr). Opening and reading whole give errno
   as the err of a Result; reading in chunks and lines are walked by for. */
/* POSIX and X/Open under -std=c11, which hides them: glibc wants
   _XOPEN_SOURCE, and macOS _DARWIN_C_SOURCE for mkdtemp and its kin,
   as kelvinc's own main.c has it */
#if defined(__APPLE__)
#define _DARWIN_C_SOURCE
#else
#define _XOPEN_SOURCE 700
#endif
#include "kelvin_prelude.h"

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

static void kv_io_fail(const char *what) {
    fflush(stdout);
    fprintf(stderr, "kelvin: %s\n", what);
    abort();
}

static char *copy_text(const void *s) {
    size_t n = strlen((const char *)s) + 1;
    char *c = malloc(n);
    if (c)
        memcpy(c, s, n);
    return c;
}

int kv_io_open(kv_io *out, const void *path, const void *mode) {
    FILE *fp = fopen((const char *)path, (const char *)mode);
    if (!fp)
        return errno ? errno : EIO;
    out->fp = fp;
    out->kind = 1;
    out->status = -1;
    out->signal = -1;
    out->path = copy_text(path); /* kept for f.path and the OS's work on it (#101) */
    return 0;
}

/* a file descriptor's IO (#86), as fdopen gives it, owned: its block
   closes the descriptor too */
int kv_io_fdopen(kv_io *out, int fd, const void *mode) {
    FILE *fp = fdopen(fd, (const char *)mode);
    if (!fp)
        return errno ? errno : EBADF;
    out->fp = fp;
    out->kind = 1;
    out->status = -1;
    out->signal = -1;
    return 0;
}

/* a shell command's IO (#87): /bin/sh -c command, through the fork and
   exec of IO.exec (#100), so that its pid is known and kill reaches it,
   which C's popen keeps to itself; its block waits for it, and status
   is then its exit code */
int kv_io_popen(kv_io *out, const void *command, const void *mode) {
    const char *const argv[] = {"/bin/sh", "-c", (const char *)command, NULL};
    return kv_io_exec(out, argv, mode, NULL, NULL, false);
}

/* a pipe (#87): its reading and its writing end, each an IO that owns
   its descriptor */
int kv_io_pipe(kv_io *reader, kv_io *writer) {
    int fds[2];
    if (pipe(fds) != 0)
        return errno ? errno : EIO;
    FILE *r = fdopen(fds[0], "r"), *w = r ? fdopen(fds[1], "w") : NULL;
    if (!r || !w) {
        int e = errno ? errno : EIO;
        if (r)
            fclose(r);
        else
            close(fds[0]);
        close(fds[1]);
        return e;
    }
    reader->fp = r;
    reader->kind = 1;
    reader->status = -1;
    reader->signal = -1;
    writer->fp = w;
    writer->kind = 1;
    writer->status = -1;
    writer->signal = -1;
    return 0;
}

/* a program run without the shell (#90): argv[0] found on the PATH, as
   execvp finds it, its output read ("r") or its input written ("w")
   through a pipe; what exec itself fails with comes back as errno,
   through a pipe closed on exec, so a missing program is ENOENT. In
   dir, when one is given, and with env's "NAME=value" entries set
   (#92), or, when fresh, with those entries as the whole environment
   (#93), the program then found on that environment's PATH, or the
   system's default; a dir that cannot be entered is reported the same
   way */
extern char **environ;

int kv_io_exec(kv_io *out, const char *const *argv, const void *mode, const void *dir, const char *const *env,
               bool fresh) {
    const char *m = (const char *)mode;
    bool reading = m[0] == 'r';
    if ((m[0] != 'r' && m[0] != 'w') || !argv || !argv[0])
        return EINVAL;
    int fds[2], report[2];
    if (pipe(fds) != 0)
        return errno ? errno : EIO;
    if (pipe(report) != 0 || fcntl(report[1], F_SETFD, FD_CLOEXEC) == -1) {
        int e = errno ? errno : EIO;
        close(fds[0]);
        close(fds[1]);
        return e;
    }
    fflush(NULL);
    pid_t pid = fork();
    if (pid < 0) {
        int e = errno ? errno : EAGAIN;
        close(fds[0]);
        close(fds[1]);
        close(report[0]);
        close(report[1]);
        return e;
    }
    if (pid == 0) { /* the child: its stdout, or stdin, is the pipe */
        close(report[0]);
        if (dup2(reading ? fds[1] : fds[0], reading ? 1 : 0) == -1)
            _exit(127);
        close(fds[0]);
        close(fds[1]);
        int e = 0;
        const char *d = (const char *)dir;
        if (d && *d && chdir(d) != 0)
            e = errno ? errno : EIO;
        if (fresh) {
            static const char *const none[] = {NULL};
            environ = (char **)(env ? env : none);
        } else {
            for (size_t i = 0; !e && env && env[i]; i++)
                if (putenv((char *)env[i]) != 0)
                    e = errno ? errno : EINVAL;
        }
        if (!e)
            execvp(argv[0], (char *const *)argv);
        if (!e)
            e = errno;
        if (write(report[1], &e, sizeof e) != (ssize_t)sizeof e)
            _exit(127);
        _exit(127);
    }
    close(report[1]);
    close(reading ? fds[1] : fds[0]);
    int e = 0;
    ssize_t got = read(report[0], &e, sizeof e);
    close(report[0]);
    if (got == (ssize_t)sizeof e) { /* exec failed: the child is gone */
        close(reading ? fds[0] : fds[1]);
        int st;
        waitpid(pid, &st, 0);
        return e ? e : EIO;
    }
    FILE *fp = fdopen(reading ? fds[0] : fds[1], reading ? "r" : "w");
    if (!fp) {
        e = errno ? errno : EIO;
        close(reading ? fds[0] : fds[1]);
        int st;
        waitpid(pid, &st, 0);
        return e;
    }
    out->fp = fp;
    out->kind = 3;
    out->status = -1;
    out->signal = -1;
    out->pid = pid;
    return 0;
}

/* a NULL-ended vector of an Array of cstr, or of String, and its count:
   the arguments, or the environment (#92) */
const char **kv_io_vector_cstrs(const uint8_t *const *at, size_t n) {
    const char **v = malloc((n + 1) * sizeof *v);
    if (!v)
        kv_io_fail("out of memory");
    for (size_t i = 0; i < n; i++)
        v[i] = (const char *)at[i];
    v[n] = NULL;
    return v;
}

const char **kv_io_vector_strings(const kv_string *at, size_t n) {
    const char **v = malloc((n + 1) * sizeof *v);
    if (!v)
        kv_io_fail("out of memory");
    for (size_t i = 0; i < n; i++)
        v[i] = (const char *)kv_bytes_cstr(&at[i].b);
    v[n] = NULL;
    return v;
}

void kv_io_vector_free(const char *const *v) { free((void *)v); }

/* the same of an Array of cstr, or of String, and its count */
int kv_io_exec_cstrs(kv_io *out, const uint8_t *const *at, size_t n, const void *mode, const void *dir,
                     const char *const *env, bool fresh) {
    const char **argv = kv_io_vector_cstrs(at, n);
    int e = kv_io_exec(out, argv, mode, dir, env, fresh);
    free(argv);
    return e;
}

int kv_io_exec_strings(kv_io *out, const kv_string *at, size_t n, const void *mode, const void *dir,
                       const char *const *env, bool fresh) {
    const char **argv = kv_io_vector_strings(at, n);
    int e = kv_io_exec(out, argv, mode, dir, env, fresh);
    free(argv);
    return e;
}

/* a signal to a process IO.popen or IO.exec started (#91, #100); false
   where there is no such process, or kill refuses */
bool kv_io_kill(kv_io *f, int sig) {
    if (f->kind != 3 || f->pid <= 0 || !f->fp)
        return false;
    return kill((pid_t)f->pid, sig) == 0;
}

int kv_io_pid(kv_io *f) { return f->kind == 3 && f->fp ? (int)f->pid : -1; }

int kv_io_status(kv_io *f) { return f->status; }

int kv_io_signal(kv_io *f) { return f->signal; }

/* the descriptor, or -1 of a closed IO */
int kv_io_fd(kv_io *f) { return f->fp ? fileno((FILE *)f->fp) : -1; }

kv_io *kv_io_std(int which) {
    static kv_io streams[3];
    if (!streams[0].fp) {
        streams[0].fp = stdin;
        streams[1].fp = stdout;
        streams[2].fp = stderr;
        streams[0].status = streams[1].status = streams[2].status = -1;
        streams[0].signal = streams[1].signal = streams[2].signal = -1;
    }
    return &streams[which < 0 || which > 2 ? 0 : which];
}

void kv_io_free(kv_io *f) {
    if (f->fp && f->kind == 3) { /* a process (#87, #90): wait for it, and keep its exit code, or its signal (#89) */
        fclose((FILE *)f->fp);
        int st = 0;
        if (waitpid((pid_t)f->pid, &st, 0) == -1) {
            f->status = f->signal = -1;
        } else {
            f->status = WIFEXITED(st) ? WEXITSTATUS(st) : -1;
            f->signal = WIFSIGNALED(st) ? WTERMSIG(st) : 0;
        }
    } else if (f->fp && f->kind == 1) {
        fclose((FILE *)f->fp);
    } else if (f->fp) {
        fflush((FILE *)f->fp);
    }
    f->fp = NULL;
    f->kind = 0;
    free(f->path);
    f->path = NULL;
}

kv_io kv_io_take(kv_io *f) {
    kv_io v = *f;
    f->fp = NULL;
    f->kind = 0;
    f->path = NULL;
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

/* the position (#84): C's feof, set once a read has met the end; ftell,
   or -1 where the stream has none, as a pipe; the length, by seeking to
   the end and back; fseek from the start, false where it fails; rewind,
   which also clears the end */
bool kv_io_eof(kv_io *f) { return f->fp && feof((FILE *)f->fp) != 0; }

long long kv_io_position(kv_io *f) {
    if (!f->fp)
        return -1;
    long v = ftell((FILE *)f->fp);
    return v < 0 ? -1 : (long long)v;
}

long long kv_io_count(kv_io *f) {
    if (!f->fp)
        return -1;
    FILE *fp = (FILE *)f->fp;
    long here = ftell(fp);
    if (here < 0 || fseek(fp, 0, SEEK_END) != 0)
        return -1;
    long end = ftell(fp);
    fseek(fp, here, SEEK_SET);
    return end < 0 ? -1 : (long long)end;
}

bool kv_io_seek(kv_io *f, long long offset) {
    if (!f->fp || offset < 0 || offset > LONG_MAX)
        return false;
    return fseek((FILE *)f->fp, (long)offset, SEEK_SET) == 0;
}

void kv_io_rewind(kv_io *f) {
    if (f->fp)
        rewind((FILE *)f->fp);
}

/* one byte (#85); false at the end. Numbers are read as a line or the
   whole text, and converted: scanf is no reader for Kelvin (#88) */
bool kv_io_read_byte(kv_io *f, uint8_t *out) {
    int c = fgetc(open_fp(f, "reading a closed IO"));
    if (c == EOF)
        return false;
    *out = (uint8_t)c;
    return true;
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

/* ---------- its path, and the OS's work on it (#101) ---------- */

static const char *path_of(kv_io *f) { return f->path ? f->path : ""; }

const uint8_t *kv_io_path(kv_io *f) { return (const uint8_t *)path_of(f); }

int kv_io_abspath(kv_io *f, kv_string *out) { return f->path ? kv_os_realpath(f->path, out) : ENOENT; }
int kv_io_listdir(kv_io *f, kv_string **out, size_t *count) { return f->path ? kv_os_listdir(f->path, out, count) : ENOENT; }
int kv_io_walk(kv_io *f, kv_string **out, size_t *count) { return f->path ? kv_os_walk(f->path, out, count) : ENOENT; }

int kv_io_glob(kv_io *f, const void *pattern, kv_string **out, size_t *count) {
    if (!f->path)
        return ENOENT;
    kv_string p = kv_os_join(f->path, pattern);
    int e = kv_os_glob(kv_bytes_cstr(&p.b), out, count);
    kv_string_free(&p);
    return e;
}

/* of the open file itself where there is one, as fstat sees it */
int kv_io_stat(kv_io *f, kv_stat *out) {
    if (f->fp) {
        struct stat st;
        if (fstat(fileno((FILE *)f->fp), &st) != 0)
            return errno ? errno : EIO;
        out->dev = (long long)st.st_dev;
        out->ino = (long long)st.st_ino;
        out->mode = (int)st.st_mode;
        out->nlink = (long long)st.st_nlink;
        out->uid = (int)st.st_uid;
        out->gid = (int)st.st_gid;
        out->size = (long long)st.st_size;
        out->atime = (double)st.st_atime;
        out->mtime = (double)st.st_mtime;
        out->ctime = (double)st.st_ctime;
        out->isdir = S_ISDIR(st.st_mode);
        out->isfile = S_ISREG(st.st_mode);
        out->islink = S_ISLNK(st.st_mode);
        return 0;
    }
    return f->path ? kv_os_stat(f->path, out) : ENOENT;
}

int kv_io_lstat(kv_io *f, kv_stat *out) { return f->path ? kv_os_lstat(f->path, out) : ENOENT; }
bool kv_io_isdir(kv_io *f) { return f->path && kv_os_isdir(f->path); }
bool kv_io_isfile(kv_io *f) { return f->path && kv_os_isfile(f->path); }
bool kv_io_islink(kv_io *f) { return f->path && kv_os_islink(f->path); }
bool kv_io_exists(kv_io *f) { return f->path && kv_os_exists(f->path); }

int kv_io_chmod(kv_io *f, int mode) {
    if (f->fp)
        return fchmod(fileno((FILE *)f->fp), (mode_t)mode) == 0 ? 0 : errno ? errno : EIO;
    return f->path ? kv_os_chmod(f->path, mode) : ENOENT;
}

int kv_io_chown(kv_io *f, int uid, int gid) {
    if (f->fp)
        return fchown(fileno((FILE *)f->fp), (uid_t)uid, (gid_t)gid) == 0 ? 0 : errno ? errno : EIO;
    return f->path ? kv_os_chown(f->path, uid, gid) : ENOENT;
}

int kv_io_truncate(kv_io *f, long long size) {
    if (f->fp) {
        fflush((FILE *)f->fp);
        return ftruncate(fileno((FILE *)f->fp), (off_t)size) == 0 ? 0 : errno ? errno : EIO;
    }
    return f->path ? kv_os_truncate(f->path, size) : ENOENT;
}

int kv_io_remove(kv_io *f) { return f->path ? kv_os_remove(f->path) : ENOENT; }

/* the path follows the file */
int kv_io_rename(kv_io *f, const void *to) {
    if (!f->path)
        return ENOENT;
    int e = kv_os_rename(f->path, to);
    if (e)
        return e;
    char *moved = copy_text(to);
    if (!moved)
        return ENOMEM;
    free(f->path);
    f->path = moved;
    return 0;
}

int kv_io_utime(kv_io *f, double atime, double mtime) { return f->path ? kv_os_utime(f->path, atime, mtime) : ENOENT; }
int kv_io_touch(kv_io *f) { return f->path ? kv_os_touch(f->path) : ENOENT; }
kv_string kv_io_basename(kv_io *f) { return kv_os_basename(path_of(f)); }
kv_string kv_io_dirname(kv_io *f) { return kv_os_dirname(path_of(f)); }
kv_string kv_io_join(kv_io *f, const void *name) { return kv_os_join(path_of(f), name); }
