/* io.c - IO (#82): stdio as an owner. A kv_io holds a FILE *, which its
   block closes when it owns it (a file it opened) and flushes when it
   does not (stdin, stdout, stderr). Opening and reading whole give errno
   as the err of a Result; reading in chunks and lines are walked by for. */
/* POSIX and X/Open under -std=c11, which hides them: glibc wants
   _XOPEN_SOURCE, and macOS _DARWIN_C_SOURCE for mkdtemp and its kin,
   as kelvinc's own main.c has it; the BSDs show it all where no macro
   asks, and hide their own extensions where _XOPEN_SOURCE asks (#192) */
#if defined(__APPLE__)
#define _DARWIN_C_SOURCE
#elif !defined(__FreeBSD__) && !defined(__NetBSD__) && !defined(__OpenBSD__) && !defined(__DragonFly__)
#define _XOPEN_SOURCE 700
#endif
#include "kelvin_prelude.h"
#include "kIO.h"

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
#if defined(__FreeBSD__)
#include <sys/param.h>
#include <sys/user.h> /* struct kinfo_file, of fcntl's F_KINFO (#192) */
#endif

static void kv_io_fail(const char *what) {
    fflush(stdout);
    fprintf(stderr, "kelvin: %s\n", what);
    kv_exit_failure();
}

static char *copy_text(const void *s) {
    size_t n = strlen((const char *)s) + 1;
    char *c = malloc(n);
    if (c)
        memcpy(c, s, n);
    return c;
}

/* a file's IO, straight (#109): when the open failed, an IO with no
   stream and the errno in .error, which .fd == -1 and the reads treat
   as a closed IO; the path is kept either way, for f.path and for the
   message of a read or a write that meets it */
kv_io kv_io_open(const void *path, const void *mode) {
    kv_io f = {0};
    f.status = f.signal = -1;
    f.path = copy_text(path); /* kept for f.path and the OS's work on it (#101) */
    FILE *fp = fopen((const char *)path, (const char *)mode);
    if (!fp) {
        f.error = errno ? errno : EIO;
        return f;
    }
    f.fp = fp;
    f.kind = 1;
    return f;
}

/* a file descriptor's IO (#86), as fdopen gives it, owned: its block
   closes the descriptor too */
kv_io kv_io_fdopen(int fd, const void *mode) {
    kv_io f = {0};
    f.status = f.signal = -1;
    FILE *fp = fdopen(fd, (const char *)mode);
    if (!fp) {
        f.error = errno ? errno : EBADF;
        return f;
    }
    f.fp = fp;
    f.kind = 1;
    return f;
}

int kv_io_error(kv_io *f) { return f->error; }

/* a shell command's IO (#87): /bin/sh -c command, through the fork and
   exec of IO.exec (#100), so that its pid is known and kill reaches it,
   which C's popen keeps to itself; its block waits for it, and status
   is then its exit code */
static int exec_into(kv_io *out, const char *const *argv, const void *mode, const void *dir, const char *const *env,
                     bool fresh);

/* a process's IO, straight (#110): .error the errno when it could not
   start, and the IO then as one that did not open */
static kv_io process_of(int e, kv_io f) {
    if (e)
        f.error = e;
    return f;
}

kv_io kv_io_popen(const void *command, const void *mode) {
    const char *const argv[] = {"/bin/sh", "-c", (const char *)command, NULL};
    kv_io f = {.status = -1, .signal = -1};
    return process_of(exec_into(&f, argv, mode, NULL, NULL, false), f);
}

/* a pipe (#87): its reading and its writing end, each an IO that owns
   its descriptor; both carry the errno of a pipe that could not be
   made (#110) */
void kv_io_pipe(kv_io *reader, kv_io *writer) {
    *reader = (kv_io){.status = -1, .signal = -1};
    *writer = (kv_io){.status = -1, .signal = -1};
    int fds[2];
    if (pipe(fds) != 0) {
        reader->error = writer->error = errno ? errno : EIO;
        return;
    }
    FILE *r = fdopen(fds[0], "r"), *w = r ? fdopen(fds[1], "w") : NULL;
    if (!r || !w) {
        int e = errno ? errno : EIO;
        if (r)
            fclose(r);
        else
            close(fds[0]);
        close(fds[1]);
        reader->error = writer->error = e;
        return;
    }
    reader->fp = r;
    reader->kind = 1;
    writer->fp = w;
    writer->kind = 1;
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

static int exec_into(kv_io *out, const char *const *argv, const void *mode, const void *dir, const char *const *env,
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

kv_io kv_io_exec(const char *const *argv, const void *mode, const void *dir, const char *const *env, bool fresh) {
    kv_io f = {.status = -1, .signal = -1};
    return process_of(exec_into(&f, argv, mode, dir, env, fresh), f);
}

/* the same of an Array of cstr, or of String, and its count */
kv_io kv_io_exec_cstrs(const uint8_t *const *at, size_t n, const void *mode, const void *dir, const char *const *env,
                       bool fresh) {
    const char **argv = kv_io_vector_cstrs(at, n);
    kv_io f = kv_io_exec(argv, mode, dir, env, fresh);
    free(argv);
    return f;
}

kv_io kv_io_exec_strings(const kv_string *at, size_t n, const void *mode, const void *dir, const char *const *env,
                         bool fresh) {
    const char **argv = kv_io_vector_strings(at, n);
    kv_io f = kv_io_exec(argv, mode, dir, env, fresh);
    free(argv);
    return f;
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
    free(f->named);
    f->named = NULL;
}

kv_io kv_io_take(kv_io *f) {
    kv_io v = *f;
    f->fp = NULL;
    f->kind = 0;
    f->path = NULL;
    f->named = NULL;
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

/* the stream, or the end of the program: of an IO that did not open
   (#109), with the open's reason, so that a program that did not ask
   f.error still learns it */
static FILE *open_fp(const kv_io *f, const char *what) {
    if (!f->fp) {
        if (f->error) {
            char msg[4096 + 256];
            snprintf(msg, sizeof msg, "%s: %s (%s an IO that did not open; ask f.error first)",
                     f->path ? f->path : "a descriptor", strerror(f->error), what);
            kv_io_fail(msg);
        }
        char msg[256];
        snprintf(msg, sizeof msg, "%s a closed IO", what);
        kv_io_fail(msg);
    }
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
    int c = fgetc(open_fp(f, "reading"));
    if (c == EOF)
        return false;
    *out = (uint8_t)c;
    return true;
}

/* whether its descriptor is a terminal (#103); false once closed */
bool kv_io_isatty(kv_io *f) { return f->fp && isatty(fileno((FILE *)f->fp)) == 1; }

/* the FILE for print and println (#83) */
void *kv_io_fp(kv_io *f) { return open_fp(f, "printing to"); }

/* the rest of the file, a Bytes straight (#107): what was read before a
   stream stopped answering, as a directory does on Linux, the error
   cleared; none of a closed IO */
kv_bytes kv_io_read_all(kv_io *f) {
    kv_bytes b = kv_bytes_new();
    if (!f->fp)
        return b;
    FILE *fp = (FILE *)f->fp;
    uint8_t buf[4096];
    size_t n;
    while ((n = fread(buf, 1, sizeof buf, fp)) > 0)
        kv_bytes_append(&b, buf, n);
    if (ferror(fp))
        clearerr(fp);
    return b;
}

/* the rest of the file as a String straight (#107); text that is not
   UTF-8 ends the program, as a line of .lines does */
kv_string kv_io_read_string(kv_io *f) {
    kv_bytes b = kv_io_read_all(f);
    size_t count;
    if (!kv_utf8_valid(b.at, b.count, &count))
        kv_io_fail("the rest of the file read by .string is not UTF-8: read .bytes, or walk .read(n)");
    return (kv_string){.b = b, .count = count};
}

/* the next n bytes at most into buf, which the loop owns; false at the end */
bool kv_io_read_chunk(kv_io *f, size_t n, kv_bytes *buf) {
    FILE *fp = open_fp(f, "reading");
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
    FILE *fp = open_fp(f, "reading");
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
    FILE *fp = open_fp(f, "writing");
    fputs((const char *)s, fp);
}

void kv_io_write_bytes(kv_io *f, const kv_bytes *b) {
    FILE *fp = open_fp(f, "writing");
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

/* the absolute path with every link followed: of the path (#104), and
   where that is gone or there is none, of the open descriptor as the
   system names it (#105), macOS's F_GETPATH or Linux's /proc/self/fd,
   a removed file's by the name it had; else the last name it found
   (#195), as of a removed file on FreeBSD, which names none; "" where
   none ever answered, as of a pipe, a closed IO, or another system */
static kv_string remember(kv_io *f, kv_string found) {
    char *kept = copy_text(kv_bytes_cstr(&found.b));
    if (kept) {
        free(f->named);
        f->named = kept;
    }
    return found;
}

kv_string kv_io_abspath(kv_io *f) {
    kv_string out = {0};
    if (f->path && kv_os_realpath(f->path, &out) == 0)
        return remember(f, out);
    char buf[PATH_MAX + 1];
    buf[0] = 0;
    int fd = f->fp ? fileno((FILE *)f->fp) : -1;
    if (fd >= 0) {
#if defined(__APPLE__)
        if (fcntl(fd, F_GETPATH, buf) != 0)
            buf[0] = 0;
#elif defined(__linux__)
        char link[64];
        snprintf(link, sizeof link, "/proc/self/fd/%d", fd);
        ssize_t n = readlink(link, buf, sizeof buf - 1);
        buf[n < 0 ? 0 : n] = 0;
        static const char gone[] = " (deleted)";
        size_t len = strlen(buf), gl = sizeof gone - 1;
        if (len > gl && !strcmp(buf + len - gl, gone)) /* a removed file, by the name it had */
            buf[len - gl] = 0;
#elif defined(__FreeBSD__) && defined(F_KINFO)
        struct kinfo_file kf; /* FreeBSD 13 and after; no /proc to ask (#192) */
        memset(&kf, 0, sizeof kf);
        kf.kf_structsize = sizeof kf;
        if (fcntl(fd, F_KINFO, &kf) == 0)
            snprintf(buf, sizeof buf, "%s", kf.kf_path);
#endif
    }
    if (buf[0] == '/')
        return remember(f, kv_string_text(buf));
    return kv_string_text(f->named ? f->named : "");
}
/* the name an IO's listdir, walk and glob (#106), remove and rename
   (#108) work by: its path while that is there, else the open
   descriptor's name as kv_io_abspath finds it, else "" */
static kv_string name_of(kv_io *f) {
    struct stat st;
    if (f->path && stat(f->path, &st) == 0)
        return kv_string_text(f->path);
    return kv_io_abspath(f);
}

/* a directory's names, every path under it, the matches of a pattern
   under it: Arrays straight, no Result (#106); none where the IO is no
   directory that can be read, or nothing names it */
void kv_io_listdir(kv_io *f, kv_string **out, size_t *count) {
    kv_string d = name_of(f);
    *out = NULL;
    *count = 0;
    if (d.b.count && kv_os_listdir(kv_bytes_cstr(&d.b), out, count) != 0)
        *out = NULL, *count = 0;
    kv_string_free(&d);
}

void kv_io_walk(kv_io *f, kv_string **out, size_t *count) {
    kv_string d = name_of(f);
    *out = NULL;
    *count = 0;
    if (d.b.count && kv_os_walk(kv_bytes_cstr(&d.b), out, count) != 0)
        *out = NULL, *count = 0;
    kv_string_free(&d);
}

void kv_io_glob(kv_io *f, const void *pattern, kv_string **out, size_t *count) {
    kv_string d = name_of(f);
    *out = NULL;
    *count = 0;
    if (d.b.count) {
        kv_string p = kv_os_join(kv_bytes_cstr(&d.b), pattern);
        if (kv_os_glob(kv_bytes_cstr(&p.b), out, count) != 0)
            *out = NULL, *count = 0;
        kv_string_free(&p);
    }
    kv_string_free(&d);
}

static void fill_stat(const struct stat *st, kv_stat *out) {
    out->dev = (long long)st->st_dev;
    out->ino = (long long)st->st_ino;
    out->mode = (int)st->st_mode;
    out->nlink = (long long)st->st_nlink;
    out->uid = (int)st->st_uid;
    out->gid = (int)st->st_gid;
    out->size = (long long)st->st_size;
    out->atime = (double)st->st_atime;
    out->mtime = (double)st->st_mtime;
    out->ctime = (double)st->st_ctime;
    out->isdir = S_ISDIR(st->st_mode);
    out->isfile = S_ISREG(st->st_mode);
    out->islink = S_ISLNK(st->st_mode);
}

/* of the open file itself, as fstat sees it: an open descriptor always
   answers, so this is a Stat and no Result (#104); once closed, the
   path's, and all zero where there is none */
kv_stat kv_io_stat(kv_io *f) {
    kv_stat out = {0};
    struct stat st;
    if (f->fp && fstat(fileno((FILE *)f->fp), &st) == 0)
        fill_stat(&st, &out);
    else if (f->path)
        kv_os_stat(f->path, &out);
    return out;
}

/* the path's own, a link's not its target's; the open file's where the
   path is gone or there is none (#104) */
kv_stat kv_io_lstat(kv_io *f) {
    kv_stat out = {0};
    if (f->path && kv_os_lstat(f->path, &out) == 0)
        return out;
    return kv_io_stat(f);
}

bool kv_io_isdir(kv_io *f) { return kv_io_stat(f).isdir; }
bool kv_io_isfile(kv_io *f) { return kv_io_stat(f).isfile; }
bool kv_io_islink(kv_io *f) { return f->path && kv_os_islink(f->path); }
bool kv_io_exists(kv_io *f) { return f->path && kv_os_exists(f->path); }

/* the operations, each a bool, true when done (#108): on the open file
   through its descriptor where the system can, chmod, chown, truncate,
   utime and touch; remove and rename by the path while it is there,
   else by the descriptor's name; false of a closed IO, a pipe, a stream */
static int fd_of(kv_io *f) { return f->fp ? fileno((FILE *)f->fp) : -1; }

bool kv_io_chmod(kv_io *f, int mode) {
    int fd = fd_of(f);
    return fd >= 0 ? fchmod(fd, (mode_t)mode) == 0 : f->path && kv_os_chmod(f->path, mode) == 0;
}

bool kv_io_chown(kv_io *f, int uid, int gid) {
    int fd = fd_of(f);
    return fd >= 0 ? fchown(fd, (uid_t)uid, (gid_t)gid) == 0 : f->path && kv_os_chown(f->path, uid, gid) == 0;
}

bool kv_io_truncate(kv_io *f, long long size) {
    int fd = fd_of(f);
    if (fd >= 0) {
        fflush((FILE *)f->fp);
        return ftruncate(fd, (off_t)size) == 0;
    }
    return f->path && kv_os_truncate(f->path, size) == 0;
}

bool kv_io_utime(kv_io *f, double atime, double mtime) {
    int fd = fd_of(f);
    return fd >= 0 ? kv_os_futime(fd, atime, mtime) == 0 : f->path && kv_os_utime(f->path, atime, mtime) == 0;
}

bool kv_io_touch(kv_io *f) {
    int fd = fd_of(f);
    return fd >= 0 ? kv_os_ftouch(fd) == 0 : f->path && kv_os_touch(f->path) == 0;
}

bool kv_io_remove(kv_io *f) {
    kv_string name = name_of(f);
    bool done = name.b.count && kv_os_remove(kv_bytes_cstr(&name.b)) == 0;
    kv_string_free(&name);
    return done;
}

/* the path follows the file */
bool kv_io_rename(kv_io *f, const void *to) {
    kv_string name = name_of(f);
    bool done = name.b.count && kv_os_rename(kv_bytes_cstr(&name.b), to) == 0;
    kv_string_free(&name);
    if (!done)
        return false;
    char *moved = copy_text(to);
    if (!moved)
        return false;
    free(f->path);
    f->path = moved;
    return true;
}

kv_string kv_io_basename(kv_io *f) { return kv_os_basename(path_of(f)); }
kv_string kv_io_dirname(kv_io *f) { return kv_os_dirname(path_of(f)); }
kv_string kv_io_join(kv_io *f, const void *name) { return kv_os_join(path_of(f), name); }
