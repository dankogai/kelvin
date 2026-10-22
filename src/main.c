/* main.c - the kelvinc driver */
/* expose mkdtemp, fork, waitpid and realpath under -std=c11 (realpath
   is an X/Open function, so glibc needs _XOPEN_SOURCE; the BSDs show it
   all where no macro asks, and less where one asks, #192) */
#if defined(__APPLE__)
#define _DARWIN_C_SOURCE
#elif !defined(__FreeBSD__) && !defined(__NetBSD__) && !defined(__OpenBSD__) && !defined(__DragonFly__)
#define _XOPEN_SOURCE 700
#endif
#include "kelvin.h"

#include <dirent.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#define KELVIN_VERSION "0.0.1"

static void usage(FILE *f) {
    fprintf(f,
            "usage: kelvinc [options] <file.k> [file.o ...] [-- program args]\n"
            "       kelvinc [options] -o <program> file.o ...\n"
            "\n"
            "options:\n"
            "  -o <path>   output path (default: source name without .k)\n"
            "  -c          compile the file into an object, file.o or the -o path, and stop\n"
            "              (#281); .o and .a files are linked with the source, or alone\n"
            "  --emit-c    write the generated C (to -o, or stdout) and stop\n"
            "  --run       build, then run the program with the args after --\n"
            "  -O          optimize (-O2)\n"
            "  -g          include debug info\n"
            "  -v          print the C compiler command\n"
            "  --no-line   omit #line directives from the generated C\n"
            "  --lib       build the file into a module (#146): M.kh, its declarations, and\n"
            "              libkM.a, with libkM.dylib or .so for C (#147), in ./modules or\n"
            "              the directory given by -o; .o and .a files after the source go\n"
            "              into the library too (#156)\n"
            "  --version   print the version\n"
            "\n"
            "environment:\n"
            "  CC            C compiler to use (default: cc)\n"
            "  KELVIN_CFLAGS extra flags for the C compiler, space-separated\n"
            "  KELVIN_HOME   where to find modules/ (kelvin_prelude.h, libkelvin.a and the\n"
            "                Kelvin files of #import <x.k>), after ./modules for <x.k>\n");
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

static bool is_dir(const char *path) {
    struct stat st;
    return stat(path, &st) == 0 && S_ISDIR(st.st_mode);
}

/* Kelvin's own modules/ (#46), which holds kelvin_prelude.h, libkelvin
   and the Kelvin files of #import <x.k>: the first of $KELVIN_HOME,
   kelvinc's directory (a build in the source tree) and its parent (an
   installation) with modules/kelvin_prelude.h, or with
   lib/kelvin/modules/kelvin_prelude.h as make install lays it out; or
   NULL */
static char *kelvin_modules(const char *argv0) {
    static char *found;
    static bool looked;
    if (looked)
        return found;
    looked = true;
    char *dir = exe_dir(argv0);
    const char *homes[] = {getenv("KELVIN_HOME"), dir, dir ? strfmt("%s/..", dir) : NULL};
    for (int i = 0; i < 3 && !found; i++)
        for (int j = 0; j < 2 && homes[i] && !found; j++) {
            char *m = strfmt("%s/%s", homes[i], j ? "lib/kelvin/modules" : "modules");
            if (file_exists(strfmt("%s/kelvin_prelude.h", m)))
                found = m;
        }
    return found;
}

/* The runtime: the prelude header and libkelvin.a in Kelvin's modules/ */
static void find_runtime(const char *argv0, char **inc, char **lib) {
    char *m = kelvin_modules(argv0);
    if (!m)
        fatal("cannot find Kelvin's modules/ (kelvin_prelude.h and libkelvin.a); set KELVIN_HOME");
    *inc = m;
    *lib = strfmt("%s/libkelvin.a", m);
    if (!file_exists(*lib))
        fatal("cannot find libkelvin.a in %s; run 'make'", m);
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
   importing file, <name> in ./modules or else in Kelvin's modules/ (#46),
   as <math.k> is the source tree's modules/math.k */
/* The libraries of the modules imported as M.kh (#143), libkM.a beside the
   header, or -lkM where only a shared libkM is, in the order imported, so
   that one a later one calls comes after it; linked before libkelvin */
static List module_libs;

static void module_library(const char *path) {
    size_t n = strlen(path);
    if (n < 4 || strcmp(path + n - 3, ".kh"))
        return;
    const char *slash = strrchr(path, '/');
    char *dir = slash ? xstrndup(path, (size_t)(slash - path)) : xstrdup(".");
    char *name = xstrndup(slash ? slash + 1 : path, (slash ? strlen(slash + 1) : n) - 3);
    char *a = strfmt("%s/libk%s.a", dir, name);
    if (file_exists(a)) {
        list_push(&module_libs, a);
        return;
    }
    if (file_exists(strfmt("%s/libk%s.dylib", dir, name)) || file_exists(strfmt("%s/libk%s.so", dir, name)))
        list_push(&module_libs, strfmt("-lk%s", name));
}

static char *import_path(Token *t, const char *argv0) {
    char *name = xstrndup(t->text + 1, strlen(t->text) - 2);
    bool bare = !strchr(name, '.'); /* <JSON> is <JSON.k> (#112), after <JSON.kh>, a module's header (#143) */
    if (bare)
        name = strfmt("%s.k", name);
    if (t->text[0] == '"') {
        const char *slash = strrchr(t->pos.file, '/');
        char *path = slash && name[0] != '/' ? strfmt("%.*s/%s", (int)(slash - t->pos.file), t->pos.file, name)
                                             : name;
        if (!kelvin_file(path))
            error_at(t->pos, "cannot find %s next to the file that imports it", t->text);
        return path;
    }
    const char *dirs[] = {"./modules", kelvin_modules(argv0)};
    for (int i = 0; i < 2; i++) {
        if (bare && dirs[i] && kelvin_file(strfmt("%s/%sh", dirs[i], name)))
            return strfmt("%s/%sh", dirs[i], name);
        if (dirs[i] && kelvin_file(strfmt("%s/%s", dirs[i], name)))
            return strfmt("%s/%s", dirs[i], name);
    }
    error_at(t->pos, "cannot find %s (%s%s) in ./modules or in Kelvin's modules/ (KELVIN_HOME, or next to kelvinc)",
             t->text, bare ? strfmt("%sh or ", name) : "", name);
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
        module_library(path);
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
        *end = (Token){TK_FILE_END, eof, path, eof.line, false, true, false};
        list_push(&out, end);
    }
    Token *all = xmalloc(sizeof(Token) * (size_t)(out.len + 1));
    for (int i = 0; i < out.len; i++)
        all[i] = *(Token *)out.data[i];
    *out_n = out.len;
    return all;
}

static List lib_objects; /* --lib: the .o and .a files given after the source, into libkM too (#156) */
static List link_objects; /* the .o and .a files linked into the program (#281) */

/* ---------- linking objects (#281) ---------- */

/* A module with a library, M.kh, and the modules it imports */
typedef struct {
    char *name, *path;
    List deps;
    bool seen;
} Module;

static List modules_found;

static Module *module_named(const char *name) {
    for (int i = 0; i < modules_found.len; i++)
        if (!strcmp(((Module *)modules_found.data[i])->name, name))
            return modules_found.data[i];
    return NULL;
}

/* Every M.kh in ./modules and Kelvin's modules/, the first of a name, as
   #import <M> finds it, with the modules its #import <N> lines name */
static void find_modules(const char *argv0) {
    const char *dirs[] = {"./modules", kelvin_modules(argv0)};
    for (int i = 0; i < 2; i++) {
        DIR *d = dirs[i] ? opendir(dirs[i]) : NULL;
        if (!d)
            continue;
        for (struct dirent *e; (e = readdir(d));) {
            size_t n = strlen(e->d_name);
            if (n < 4 || strcmp(e->d_name + n - 3, ".kh"))
                continue;
            char *name = xstrndup(e->d_name, n - 3);
            if (module_named(name))
                continue;
            Module *m = xcalloc(1, sizeof *m);
            m->name = name;
            m->path = strfmt("%s/%s", dirs[i], e->d_name);
            for (char *line = read_file(m->path); line; line = strchr(line, '\n') ? strchr(line, '\n') + 1 : NULL) {
                if (strncmp(line, "#import <", 9))
                    continue;
                char *end = strchr(line + 9, '>');
                char *dep = end ? xstrndup(line + 9, (size_t)(end - line - 9)) : NULL;
                if (dep && !strchr(dep, '.') && !strchr(dep, '\n'))
                    list_push(&m->deps, dep);
            }
            list_push(&modules_found, m);
        }
        closedir(d);
    }
}

/* m after the modules it imports */
static void visit_module(Module *m, List *order) {
    if (m->seen)
        return;
    m->seen = true;
    for (int i = 0; i < m->deps.len; i++) {
        Module *d = module_named(m->deps.data[i]);
        if (d)
            visit_module(d, order);
    }
    list_push(order, m);
}

/* Objects may call any module, which their imports no longer show: the
   libraries of all, each before the ones it imports, so that C's linker,
   reading them once in order, finds what one calls in one after it. A
   static library brings in only what is called. */
static void all_module_libs(const char *argv0) {
    find_modules(argv0);
    List order = {0};
    for (int i = 0; i < modules_found.len; i++)
        visit_module(modules_found.data[i], &order);
    module_libs.len = 0;
    for (int i = order.len - 1; i >= 0; i--)
        module_library(((Module *)order.data[i])->path);
}

static bool ends_with(const char *s, const char *suffix) {
    size_t n = strlen(s), m = strlen(suffix);
    return n >= m && !strcmp(s + n - m, suffix);
}

/* the shared library beside a static one, libx.dylib or libx.so for
   libx.a, where there is one; else the static one */
static char *shared_of(const char *a) {
    size_t n = strlen(a);
    if (n < 3 || strcmp(a + n - 2, ".a"))
        return xstrdup(a);
    const char *exts[] = {".dylib", ".so"};
    for (int i = 0; i < 2; i++) {
        char *so = strfmt("%.*s%s", (int)(n - 2), a, exts[i]);
        if (file_exists(so))
            return so;
    }
    return xstrdup(a);
}

/* libkM.dylib or libkM.so from the module's object (#147): linked against
   the shared libkelvin and the shared libraries of the modules it imports,
   or their static ones where there is no shared one */
static int link_shared(const char *cc, const char *lib_dir, const char *lib_name, const char *obj, const char *rt_inc,
                       const char *rt_lib, bool verbose) {
    List args = {0};
    list_push(&args, (void *)cc);
#ifdef __APPLE__
    char *so = strfmt("%s/libk%s.dylib", lib_dir, lib_name);
    list_push(&args, "-dynamiclib");
    list_push(&args, "-install_name");
    list_push(&args, strfmt("@rpath/libk%s.dylib", lib_name));
#else
    char *so = strfmt("%s/libk%s.so", lib_dir, lib_name);
    list_push(&args, "-shared");
    list_push(&args, strfmt("-Wl,-soname,libk%s.so", lib_name));
#endif
    list_push(&args, "-o");
    list_push(&args, so);
    list_push(&args, (void *)obj);
    for (int i = 0; i < lib_objects.len; i++)
        list_push(&args, lib_objects.data[i]);
    if (is_dir("./modules"))
        list_push(&args, "-L./modules");
    list_push(&args, strfmt("-L%s", rt_inc));
    for (int i = 0; i < module_libs.len; i++)
        list_push(&args, shared_of(module_libs.data[i]));
    list_push(&args, shared_of(rt_lib));
    list_push(&args, "-lm");
    list_push(&args, NULL);
    unlink(so);
    return run((char **)args.data, verbose);
}

static bool text_in(List *l, const char *s) {
    for (int i = 0; i < l->len; i++)
        if (!strcmp(l->data[i], s))
            return true;
    return false;
}

static char *default_output(const char *src) {
    const char *base = strrchr(src, '/');
    base = base ? base + 1 : src;
    size_t n = strlen(base);
    if (n > 2 && !strcmp(base + n - 2, ".k"))
        n -= 2;
    return xstrndup(base, n);
}

/* kelvinc -o program a.o b.o (#281): objects kelvinc -c made, and .a
   files, linked with the libraries of all modules and libkelvin; the
   program is named after the first object without -o */
static int link_only(const char *argv0, const char *out_path, bool run_after, bool verbose, int prog_argc,
                     char **prog_argv) {
    char *rt_inc, *rt_lib;
    find_runtime(argv0, &rt_inc, &rt_lib);
    all_module_libs(argv0);
    char *dir = NULL;
    if (run_after && !out_path) {
        const char *tmpdir = getenv("TMPDIR");
        dir = strfmt("%s/kelvinc-XXXXXX", tmpdir && *tmpdir ? tmpdir : "/tmp");
        if (!mkdtemp(dir))
            fatal("cannot create a temporary directory");
    }
    const char *first = link_objects.data[0];
    char *exe = out_path ? xstrdup(out_path) : dir ? strfmt("%s/program", dir) : default_output(first);
    if (!out_path && !dir) /* a.o is a, as file.k is file */
        exe[strlen(exe) - 2] = '\0';
    const char *cc = getenv("CC");
    List args = {0};
    list_push(&args, (void *)(cc && *cc ? cc : "cc"));
    list_push(&args, "-o");
    list_push(&args, exe);
    for (int i = 0; i < link_objects.len; i++)
        list_push(&args, link_objects.data[i]);
    if (is_dir("./modules"))
        list_push(&args, "-L./modules");
    list_push(&args, strfmt("-L%s", rt_inc));
    const char *extra = getenv("KELVIN_CFLAGS"); /* -fsanitize=address links its runtime too */
    char *flags = xstrdup(extra ? extra : "");
    for (char *tok = strtok(flags, " \t\n"); tok; tok = strtok(NULL, " \t\n"))
        list_push(&args, tok);
    for (int i = 0; i < module_libs.len; i++)
        list_push(&args, module_libs.data[i]);
    list_push(&args, rt_lib);
    list_push(&args, "-lm");
    list_push(&args, NULL);
    int rc = run((char **)args.data, verbose);
    if (rc != 0 || !run_after) {
        if (dir)
            rmdir(dir);
        return rc;
    }
    char **pargv = xcalloc((size_t)prog_argc + 2, sizeof(char *));
    pargv[0] = exe;
    for (int i = 0; i < prog_argc; i++)
        pargv[i + 1] = prog_argv[i];
    rc = run(pargv, false);
    if (dir) {
        unlink(exe);
        rmdir(dir);
    }
    return rc;
}

int main(int argc, char **argv) {
    const char *src_path = NULL, *out_path = NULL;
    bool emit_c = false, run_after = false, optimize = false, debug = false, verbose = false, compile_only = false;
    bool line_directives = true, lib = false;
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
        } else if (!strcmp(a, "-c")) {
            compile_only = true;
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
        } else if (!strcmp(a, "--lib")) {
            lib = true;
            lib_mode = true;
        } else if (!strcmp(a, "--version")) {
            printf("kelvinc %s\n", KELVIN_VERSION);
            return 0;
        } else if (!strcmp(a, "-h") || !strcmp(a, "--help")) {
            usage(stdout);
            return 0;
        } else if (a[0] == '-') {
            usage(stderr);
            fatal("unknown option '%s'", a);
        } else if (src_path && lib && (ends_with(a, ".o") || ends_with(a, ".a"))) {
            list_push(&lib_objects, a); /* an object or an archive the library holds too (#156) */
        } else if (!lib && (ends_with(a, ".o") || ends_with(a, ".a"))) {
            list_push(&link_objects, a); /* linked into the program (#281) */
        } else if (src_path) {
            fatal("only one source file is supported for now");
        } else {
            src_path = a;
        }
    }
    if (compile_only && (lib || emit_c || run_after))
        fatal("-c makes an object, which %s does not", lib ? "--lib" : emit_c ? "--emit-c" : "--run");
    if (compile_only && link_objects.len)
        fatal("-c compiles one source into an object, and links nothing: '%s' is linked without -c",
              (char *)link_objects.data[0]);
    if (!src_path && link_objects.len && !emit_c && !compile_only)
        return link_only(argv[0], out_path, run_after, verbose, prog_argc, prog_argv);
    if (!src_path) {
        usage(stderr);
        return 2;
    }

    char *src = read_file(src_path);
    set_source(src_path, src);
    int ntoks;
    Token *toks = lex(src_path, src, &ntoks);
    if (lib) /* a library's functions are named by their types, as a program's prototypes of them are (#146) */
        for (int i = 0; i < ntoks; i++)
            toks[i].imported = true;
    imported_already(src_path); /* the main file is brought in already */
    toks = with_imports(toks, ntoks, &ntoks, argv[0]);
    Program *prog = parse(toks, ntoks);
    char *c_code = gen_program(prog, line_directives);
    if (link_objects.len) /* the objects may call modules the source does not import (#281) */
        all_module_libs(argv[0]);
    char *lib_dir = NULL, *lib_name = NULL;
    if (lib) {
        /* M.kh and libkM.a, in ./modules or the directory -o names */
        lib_dir = out_path ? xstrdup(out_path) : xstrdup("./modules");
        if (!is_dir(lib_dir) && mkdir(lib_dir, 0777) != 0)
            fatal("cannot create '%s'", lib_dir);
        lib_name = default_output(src_path);
        const char *base = strrchr(lib_name, '/');
        if (base)
            lib_name = xstrdup(base + 1);
        char *kh = strfmt("// %s.kh - the module %s (#146), made by kelvinc --lib from %s: its declarations,\n"
                          "// the bodies dropped, which libk%s.a beside it defines; #import <%s> brings it in\n%s",
                          lib_name, lib_name, src_path, lib_name, lib_name, gen_header(prog));
        write_file(strfmt("%s/%s.kh", lib_dir, lib_name), kh);
    }

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
           and z * w == w * z in modules/math.k (#43) */
        "-ffp-contract=off",
    };
    List cc_args = {0};
    for (size_t i = 0; i < sizeof base_args / sizeof base_args[0]; i++)
        list_push(&cc_args, (void *)base_args[i]);
    /* #import "x.h" as C looks next to the .k file, as #include would */
    const char *slash = strrchr(src_path, '/');
    list_push(&cc_args, !slash ? "-I." : slash == src_path ? "-I/" : strfmt("-I%.*s", (int)(slash - src_path), src_path));
    /* C looks for headers and libraries in ./modules and Kelvin's modules/
       too (#46), where the prelude header is a system header: its macros
       raise no warnings. A ./modules with a prelude header of its own,
       another Kelvin's, comes after the system's, so that the header is
       the one of the libkelvin.a linked. */
    char *here = realpath("./modules", NULL), *home = realpath(rt_inc, NULL);
    if (here && is_dir(here) && !(home && !strcmp(here, home))) {
        list_push(&cc_args, file_exists("./modules/kelvin_prelude.h") ? "-idirafter" : "-I");
        list_push(&cc_args, "./modules");
        list_push(&cc_args, "-L./modules");
    }
    list_push(&cc_args, "-isystem");
    list_push(&cc_args, rt_inc);
    list_push(&cc_args, strfmt("-L%s", rt_inc));
    char *obj_path = strfmt("%s/libk%s.o", dir, lib_name ? lib_name : "");
    if (lib) { /* an object, then libkM.a from it (#146) */
        list_push(&cc_args, "-c");
        list_push(&cc_args, "-fPIC");
        list_push(&cc_args, "-o");
        list_push(&cc_args, obj_path);
    } else if (compile_only) { /* an object, file.o or the -o path (#281) */
        list_push(&cc_args, "-c");
        list_push(&cc_args, "-o");
        list_push(&cc_args, out_path ? xstrdup(out_path) : strfmt("%s.o", default_output(src_path)));
    } else {
        list_push(&cc_args, "-o");
        list_push(&cc_args, exe);
    }
    list_push(&cc_args, c_path);
    for (int i = 0; i < link_objects.len; i++) /* after the program's C, before the libraries (#281) */
        list_push(&cc_args, link_objects.data[i]);
    /* extra flags, split on whitespace (e.g. -fsanitize=undefined), after
       the program, so that a -lfoo there links what it uses (#46) */
    const char *extra = getenv("KELVIN_CFLAGS");
    char *flags = xstrdup(extra ? extra : "");
    for (char *tok = strtok(flags, " \t\n"); tok; tok = strtok(NULL, " \t\n"))
        list_push(&cc_args, tok);
    for (int i = 0; i < module_libs.len; i++) /* the modules' libraries (#143), before libkelvin, which they use */
        list_push(&cc_args, module_libs.data[i]);
    const char *tail_args[] = {rt_lib, "-lm", NULL};
    for (size_t i = 0; i < sizeof tail_args / sizeof tail_args[0]; i++)
        list_push(&cc_args, (void *)tail_args[i]);
    if (lib || compile_only) { /* no libraries: an object only; the list ends with NULL */
        if (cc_args.len && !cc_args.data[cc_args.len - 1])
            cc_args.len--;
        while (cc_args.len && (cc_args.data[cc_args.len - 1] == (void *)rt_lib ||
                               !strcmp(cc_args.data[cc_args.len - 1], "-lm") ||
                               text_in(&module_libs, cc_args.data[cc_args.len - 1])))
            cc_args.len--;
        int kept = 0;
        for (int i = 0; i < cc_args.len; i++) /* and no -L: nothing is linked */
            if (strncmp(cc_args.data[i], "-L", 2))
                cc_args.data[kept++] = cc_args.data[i];
        cc_args.len = kept;
        list_push(&cc_args, NULL);
    }
    char **cc_argv = (char **)cc_args.data;
    int rc = run(cc_argv, verbose);
    unlink(c_path);
    if (rc != 0) {
        rmdir(dir);
        return rc;
    }
    if (lib) {
        char *a = strfmt("%s/libk%s.a", lib_dir, lib_name);
        unlink(a);
        List ar_args = {0};
        list_push(&ar_args, "ar");
        list_push(&ar_args, "rcs");
        list_push(&ar_args, a);
        list_push(&ar_args, obj_path);
        for (int i = 0; i < lib_objects.len; i++)
            if (ends_with(lib_objects.data[i], ".o"))
                list_push(&ar_args, lib_objects.data[i]);
        list_push(&ar_args, NULL);
        rc = run((char **)ar_args.data, verbose);
        if (rc == 0) /* and the shared libkM, for C and other toolchains (#147) */
            rc = link_shared(cc_argv[0], lib_dir, lib_name, obj_path, rt_inc, rt_lib, verbose);
        unlink(obj_path);
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
