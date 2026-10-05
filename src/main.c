/* main.c - the kelvinc driver */
/* expose mkdtemp, fork, waitpid and realpath under -std=c11 (realpath
   is an X/Open function, so glibc needs _XOPEN_SOURCE) */
#if defined(__APPLE__)
#define _DARWIN_C_SOURCE
#else
#define _XOPEN_SOURCE 700
#endif
#include "kelvin.h"

#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#define KELVIN_VERSION "0.0.1"

static void usage(FILE *f) {
    fprintf(f,
            "usage: kelvinc [options] <file.k> [-- program args]\n"
            "\n"
            "options:\n"
            "  -o <path>   output path (default: source name without .k)\n"
            "  --emit-c    write the generated C (to -o, or stdout) and stop\n"
            "  --run       build, then run the program with the args after --\n"
            "  -O          optimize (-O2)\n"
            "  -g          include debug info\n"
            "  -v          print the C compiler command\n"
            "  --no-line   omit #line directives from the generated C\n"
            "  --version   print the version\n"
            "\n"
            "environment:\n"
            "  CC            C compiler to use (default: cc)\n"
            "  KELVIN_CFLAGS extra flags for the C compiler, space-separated\n"
            "  KELVIN_HOME   where to find kelvin_prelude.h, libkelvin.a and the Kelvin files\n"
            "                of #import <lib/x.k>\n");
}

static char *read_file(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f)
        fatal("cannot open '%s'", path);
    Buf b = {0};
    buf_puts(&b, "");
    char chunk[65536];
    size_t n;
    while ((n = fread(chunk, 1, sizeof chunk, f)) > 0)
        buf_putn(&b, chunk, n);
    fclose(f);
    if (strlen(b.buf) != b.len)
        fatal("'%s' contains a NUL byte", path);
    return b.buf;
}

static void write_file(const char *path, const char *text) {
    FILE *f = fopen(path, "wb");
    if (!f)
        fatal("cannot write '%s'", path);
    fputs(text, f);
    if (fclose(f) != 0)
        fatal("cannot write '%s'", path);
}

static int run(char **argv, bool verbose) {
    if (verbose) {
        for (int i = 0; argv[i]; i++)
            fprintf(stderr, "%s%s", i ? " " : "", argv[i]);
        fprintf(stderr, "\n");
    }
    fflush(stdout);
    pid_t pid = fork();
    if (pid < 0)
        fatal("fork failed");
    if (pid == 0) {
        execvp(argv[0], argv);
        fprintf(stderr, "kelvinc: cannot run '%s'\n", argv[0]);
        _exit(127);
    }
    int status;
    if (waitpid(pid, &status, 0) < 0)
        fatal("waitpid failed");
    if (WIFEXITED(status))
        return WEXITSTATUS(status);
    return 128 + WTERMSIG(status);
}

/* The directory that holds the running kelvinc, or NULL. */
static char *exe_dir(const char *argv0) {
    char *path = NULL;
    if (strchr(argv0, '/')) {
        path = realpath(argv0, NULL);
    } else {
        const char *env = getenv("PATH");
        char *dirs = xstrdup(env ? env : "");
        for (char *d = strtok(dirs, ":"); d && !path; d = strtok(NULL, ":")) {
            char *candidate = strfmt("%s/%s", *d ? d : ".", argv0);
            if (access(candidate, X_OK) == 0)
                path = realpath(candidate, NULL);
        }
    }
    if (!path)
        return NULL;
    *strrchr(path, '/') = '\0';
    return path;
}

static bool file_exists(const char *path) { return access(path, R_OK) == 0; }

/* A Kelvin file to import is a readable file, not a directory (#40) */
static bool kelvin_file(const char *path) {
    struct stat st;
    return file_exists(path) && stat(path, &st) == 0 && S_ISREG(st.st_mode);
}

/* Find the prelude header and libkelvin.a under `home`, laid out either
   as the source tree (runtime/, libkelvin.a) or as an installation
   (include/, lib/). */
static bool runtime_in(const char *home, char **inc, char **lib) {
    if (!home)
        return false;
    const char *layouts[][2] = {{"runtime", "."}, {"include", "lib"}};
    for (int i = 0; i < 2; i++) {
        char *h = strfmt("%s/%s", home, layouts[i][0]);
        char *l = strfmt("%s/%s/libkelvin.a", home, layouts[i][1]);
        if (file_exists(strfmt("%s/kelvin_prelude.h", h)) && file_exists(l)) {
            *inc = h;
            *lib = l;
            return true;
        }
    }
    return false;
}

/* The runtime is looked for in $KELVIN_HOME, next to kelvinc (a build in
   the source tree), and in kelvinc's parent directory (an installation). */
static void find_runtime(const char *argv0, char **inc, char **lib) {
    char *dir = exe_dir(argv0);
    if (runtime_in(getenv("KELVIN_HOME"), inc, lib) || runtime_in(dir, inc, lib) ||
        (dir && runtime_in(strfmt("%s/..", dir), inc, lib)))
        return;
    fatal("cannot find the Kelvin runtime (kelvin_prelude.h and libkelvin.a); run 'make', or set KELVIN_HOME");
}

/* ---------- #import of Kelvin files (#40) ---------- */

/* The Kelvin files already brought in, by their device and inode, so that
   another path to one, a hard link too, is the same file */
static List imported;

static bool imported_already(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0)
        return false;
    char *id = strfmt("%lld:%lld", (long long)st.st_dev, (long long)st.st_ino);
    for (int j = 0; j < imported.len; j++)
        if (!strcmp(imported.data[j], id))
            return true;
    list_push(&imported, id);
    return false;
}

/* The file that #import <name> or "name" means: "name" next to the
   importing file, <name> under Kelvin's home ($KELVIN_HOME, kelvinc's
   directory, or its parent), as <lib/complex.k> is the source tree's
   lib/complex.k */
static char *import_path(Token *t, const char *argv0) {
    char *name = xstrndup(t->text + 1, strlen(t->text) - 2);
    if (t->text[0] == '"') {
        const char *slash = strrchr(t->pos.file, '/');
        char *path = slash && name[0] != '/' ? strfmt("%.*s/%s", (int)(slash - t->pos.file), t->pos.file, name)
                                             : name;
        if (!kelvin_file(path))
            error_at(t->pos, "cannot find %s next to the file that imports it", t->text);
        return path;
    }
    char *dir = exe_dir(argv0);
    const char *homes[] = {getenv("KELVIN_HOME"), dir, dir ? strfmt("%s/..", dir) : NULL};
    for (int i = 0; i < 3; i++)
        if (homes[i] && kelvin_file(strfmt("%s/%s", homes[i], name)))
            return strfmt("%s/%s", homes[i], name);
    error_at(t->pos, "cannot find %s in Kelvin's home (KELVIN_HOME, or next to kelvinc)", t->text);
}

/* The tokens with each #import of a Kelvin file followed by that file's
   tokens, once per program, so that its declarations are compiled as if
   written there. The import stays, and a TK_FILE_END follows the file, so
   that the parser sees where each file begins and ends: a declaration
   there ends, an unfinished one is an error in its own file, and an
   import inside a body is an error at the import. A "header.h" that an
   imported file imports as C is looked for next to that file, as C's
   #include "..." does, so it is written with its full path. */
static Token *with_imports(Token *toks, int n, int *out_n, const char *argv0) {
    List out = {0};
    for (int i = 0; i < n; i++) {
        Token *t = xmalloc(sizeof *t);
        *t = toks[i];
        list_push(&out, t);
        if (t->imported && t->kind == TK_IMPORT && t->text[0] == '"' && t->text[1] != '/') {
            /* the importing file's directory, made absolute, and the name
               as written, so that a header that is a symlink keeps its own
               directory for its own #include "..." */
            const char *slash = strrchr(t->pos.file, '/');
            char *dir = realpath(slash ? strfmt("%.*s", (int)(slash - t->pos.file), t->pos.file) : ".", NULL);
            char *name = xstrndup(t->text + 1, strlen(t->text) - 2);
            char *path = dir ? strfmt("%s/%s", dir, name) : NULL;
            if (path && file_exists(path) && !strpbrk(path, "\"\n"))
                t->text = strfmt("\"%s\"", path);
        }
        if (toks[i].kind != TK_IMPORT_K)
            continue;
        char *path = import_path(&toks[i], argv0);
        if (imported_already(path))
            continue;
        char *src = read_file(path);
        set_source(path, src);
        int m, k;
        Token *more = lex(path, src, &m);
        for (int j = 0; j < m; j++)
            more[j].imported = true;
        Pos eof = more[m - 1].pos;
        more = with_imports(more, m - 1, &k, argv0); /* without its end of file */
        for (int j = 0; j < k; j++) {
            Token *u = xmalloc(sizeof *u);
            *u = more[j];
            list_push(&out, u);
        }
        Token *end = xmalloc(sizeof *end);
        *end = (Token){TK_FILE_END, eof, path, eof.line, false, true};
        list_push(&out, end);
    }
    Token *all = xmalloc(sizeof(Token) * (size_t)(out.len + 1));
    for (int i = 0; i < out.len; i++)
        all[i] = *(Token *)out.data[i];
    *out_n = out.len;
    return all;
}

static char *default_output(const char *src) {
    const char *base = strrchr(src, '/');
    base = base ? base + 1 : src;
    size_t n = strlen(base);
    if (n > 2 && !strcmp(base + n - 2, ".k"))
        n -= 2;
    return xstrndup(base, n);
}

int main(int argc, char **argv) {
    const char *src_path = NULL, *out_path = NULL;
    bool emit_c = false, run_after = false, optimize = false, debug = false, verbose = false;
    bool line_directives = true;
    int prog_argc = 0;
    char **prog_argv = NULL;

    for (int i = 1; i < argc; i++) {
        char *a = argv[i];
        if (!strcmp(a, "--")) {
            prog_argv = argv + i + 1;
            prog_argc = argc - i - 1;
            break;
        } else if (!strcmp(a, "-o")) {
            if (++i >= argc)
                fatal("-o needs a path");
            out_path = argv[i];
        } else if (!strcmp(a, "--emit-c")) {
            emit_c = true;
        } else if (!strcmp(a, "--run")) {
            run_after = true;
        } else if (!strcmp(a, "-O")) {
            optimize = true;
        } else if (!strcmp(a, "-g")) {
            debug = true;
        } else if (!strcmp(a, "-v")) {
            verbose = true;
        } else if (!strcmp(a, "--no-line")) {
            line_directives = false;
        } else if (!strcmp(a, "--version")) {
            printf("kelvinc %s\n", KELVIN_VERSION);
            return 0;
        } else if (!strcmp(a, "-h") || !strcmp(a, "--help")) {
            usage(stdout);
            return 0;
        } else if (a[0] == '-') {
            usage(stderr);
            fatal("unknown option '%s'", a);
        } else if (src_path) {
            fatal("only one source file is supported for now");
        } else {
            src_path = a;
        }
    }
    if (!src_path) {
        usage(stderr);
        return 2;
    }

    char *src = read_file(src_path);
    set_source(src_path, src);
    int ntoks;
    Token *toks = lex(src_path, src, &ntoks);
    imported_already(src_path); /* the main file is brought in already */
    toks = with_imports(toks, ntoks, &ntoks, argv[0]);
    Program *prog = parse(toks, ntoks);
    char *c_code = gen_program(prog, line_directives);

    if (emit_c) {
        if (out_path)
            write_file(out_path, c_code);
        else
            fputs(c_code, stdout);
        return 0;
    }

    const char *tmpdir = getenv("TMPDIR");
    char *dir = strfmt("%s/kelvinc-XXXXXX", tmpdir && *tmpdir ? tmpdir : "/tmp");
    if (!mkdtemp(dir))
        fatal("cannot create a temporary directory");
    char *c_path = strfmt("%s/program.c", dir);
    write_file(c_path, c_code);

    char *rt_inc, *rt_lib;
    find_runtime(argv[0], &rt_inc, &rt_lib);
    char *exe = out_path ? xstrdup(out_path) : run_after ? strfmt("%s/program", dir) : default_output(src_path);
    const char *cc = getenv("CC");
    const char *base_args[] = {
        cc && *cc ? cc : "cc",
        "-std=c11",
        optimize ? "-O2" : "-O0",
        debug ? "-g" : "-g0",
        /* Kelvin's u8 is C's unsigned char, while string literals and libc
           use plain char. They are ABI-identical, so silence C's
           complaints about the mix. */
        "-Wno-unknown-warning-option",
        "-Wno-pointer-sign",
        "-Wno-incompatible-library-redeclaration",
        "-Wno-builtin-declaration-mismatch",
        /* gcc on x86-64 notes that passing a struct with a flexible array
           member changed ABI in GCC 4.4, e.g. for a derived .cstr */
        "-Wno-psabi",
        /* a * b + c is rounded twice, as gcc does in ISO C mode, where
           clang would fuse it into one fma(): the same results from both,
           and z * w == w * z in lib/complex.k (#43) */
        "-ffp-contract=off",
    };
    List cc_args = {0};
    for (size_t i = 0; i < sizeof base_args / sizeof base_args[0]; i++)
        list_push(&cc_args, (void *)base_args[i]);
    /* #import "x.h" as C looks next to the .k file, as #include would */
    const char *slash = strrchr(src_path, '/');
    list_push(&cc_args, !slash ? "-I." : slash == src_path ? "-I/" : strfmt("-I%.*s", (int)(slash - src_path), src_path));
    /* the prelude header is a system header: its macros raise no warnings */
    list_push(&cc_args, "-isystem");
    list_push(&cc_args, rt_inc);
    /* extra flags, split on whitespace (e.g. -fsanitize=undefined) */
    const char *extra = getenv("KELVIN_CFLAGS");
    char *flags = xstrdup(extra ? extra : "");
    for (char *tok = strtok(flags, " \t\n"); tok; tok = strtok(NULL, " \t\n"))
        list_push(&cc_args, tok);
    const char *tail_args[] = {"-o", exe, c_path, rt_lib, "-lm", NULL};
    for (size_t i = 0; i < sizeof tail_args / sizeof tail_args[0]; i++)
        list_push(&cc_args, (void *)tail_args[i]);
    char **cc_argv = (char **)cc_args.data;
    int rc = run(cc_argv, verbose);
    unlink(c_path);
    if (rc != 0) {
        rmdir(dir);
        return rc;
    }

    if (!run_after) {
        rmdir(dir);
        return 0;
    }
    char **pargv = xcalloc((size_t)prog_argc + 2, sizeof(char *));
    pargv[0] = exe;
    for (int i = 0; i < prog_argc; i++)
        pargv[i + 1] = prog_argv[i];
    rc = run(pargv, false);
    if (!out_path)
        unlink(exe);
    rmdir(dir);
    return rc;
}
