# Self-hosting Kelvin: experimental

**Can Kelvin compile itself?** For a subset, yes. `kc` is a compiler
written in Kelvin alone. It reads the subset it is written in, writes C
as kelvinc does, and hands that C to `cc`. Built in stages, as gcc
bootstraps itself, it reaches a fixpoint (#204).

- **Experimental** (#230), no longer a proof of concept: CI builds it
  and checks its fixpoint on every push (#228), but its subset, its
  messages and its C may still change with each step.

- **Kelvin, and the platform's C:** a self-hosted Kelvin may depend on
  libc, or libSystem on macOS, as C does: Kelvin embraces C rather than
  refusing it.
  - What would be cheating is C of its own: `#inline C`, or C headers
    and libraries written for it.
  - kc uses less still: the prelude (`String`, `Array`, `println`) and
    `<IO>` to read the source, write the C and run `cc`.
- **In CI** (#228): the `selfhost` jobs run `bootstrap.sh` and
  `sanitize.sh` with gcc and clang on Ubuntu, and clang on macOS.

## Files

| File | What it is |
|---|---|
| [kc.k](kc.k) | the driver: options, reading files and their imports, writing the C, running `cc` |
| [lex.k](lex.k) | the tokens |
| [parse.k](parse.k) | the tree and the types |
| [gen.k](gen.k) | the C |
| [sample.k](sample.k) | a program of the subset, built by both compilers, which must print the same |
| [bootstrap.sh](bootstrap.sh) | the stages and their checks |
| [sanitize.sh](sanitize.sh) | kc built with ASan and UBSan, which must write the same C (#228) |

## The stages

```sh
selfhost/bootstrap.sh
selfhost/sanitize.sh
```

| Stage | Built by | From |
|---|---|---|
| stage1 | kelvinc | `selfhost/kc.k` |
| stage2 | stage1 | `selfhost/kc.k` |
| stage3 | stage2 | `selfhost/kc.k` |

- **The fixpoint:** stage2 and stage3 are both kc built by kc, so the C
  each writes of kc is the same, byte for byte (`build/selfhost/stage2.c`
  and `stage3.c`).
- **The sample:** stage3 builds `sample.k`, whose output must be what
  kelvinc's build of it prints.
- **The compiler:** `CC` picks the C compiler of every stage, and of
  kelvinc's build of the sample; CI runs gcc and clang.
- **Sanitizers** (#228): `sanitize.sh` builds kc from stage2's C with
  ASan and UBSan, and its C of `kc.k` and of `sample.k` must be the
  stages' own, with no memory error and no undefined behavior.
- Everything goes into `build/selfhost/`; nothing is removed.

## Using kc

```sh
build/selfhost/stage3 program.k -o program [-c program.c] [-m modules] [-cc compiler]
```

- `-c` keeps the C there; without `-o`, kc writes the C alone.
  - Without `-c`, the C is a temporary file, `$TMPDIR/kc-<pid>.c`, or in
    `/tmp`, removed once `cc` is done (#207).
- `-m` names the directory of `kelvin_prelude.h` and the libraries.
  - Without it: `$KELVIN_HOME/modules`, as kelvinc reads `KELVIN_HOME`,
    else `modules`, from the top of the repository.
- `-cc` names the C compiler; without it, `$CC`, else `cc`.

## The subset

kc reads what it is written in, and little more.

- **Declarations:** `let f(x:T, ...):R { }`, a prototype without a body,
  `struct` of plain members, `enum` of names, C's (#210), global `let`
  and `var`, `#import <IO>`, `#import "x.k"`, and `#import <x.h> as C`
  (#207).
- **Enums with values** (#215): `enum item { none; num: int64; text:
  String }`, written as kelvinc writes one: a struct of a tag and a
  union, with `_kv_T_make_c`, `_at_c` (checked) and `_set_c`, and
  `_free`, `_take` and `_copy` where a case owns.
  - `T.c(v)` makes one, a local owner moving in, and `T.none` one of no
    value; `v.c` reads the case's value, checked; `v.c = x` sets the
    case, freeing what it held; `v.is(c)`.
  - `switch v { case none: ... case num(n): ... }` binds the case's
    value, which the enum still owns; every case is named, or there is
    `default:`.
- **Optional and Result** (#217): `T?`, `Optional<T>` and
  `Result<T, E>`, which kc makes as the enums with values kelvinc makes:
  `struct _kv_opt_T` of `none` and `some`, `struct _kv_res_T_E` of `ok`
  and `err`.
  - `none`, `ok(v)` and `err(e)` are read by the type that takes them,
    a variable's, a return's, an assignment's or a parameter's; a `T`
    where a `T?` goes is `some(T)`. `some(v)` is a pattern alone, as in
    kelvinc.
    - Since #221 a program needs no enum of its own with a case `none`
      for that: kc asked the type of a bare `none` in a `return` and in
      an argument, and found no name.
    - So in a struct's `{a, b}`, whose members kc reads by their
      fields' types since #225.
  - `$[T]?` is an Optional of an Array (#221), and `T??` one of a `T?`
    (#229).
  - A number literal is `some(n)` of any number's Optional, `{a, b}` is
    `some` of a struct, and a `T` of a `T??` is wrapped twice (#229).
  - **Printed** (#229) as kelvinc prints it: `some(3)`, `none`,
    `some("kelvin")`, `ok(5)`, `err("bad")`, an enum's `num(5)`, a
    struct's `{x: 1, y: 2}`, and an Array's `[1, 2]`, `[]` where empty
    (#230), and a Dictionary's `{"ann": 31}`, `{}` where empty, its
    entries in the order added, a String key quoted (#268).
    - Each type printed gets a `_kv_show_T` of kelvinc's form, declared
      before the functions and written after them; `print` calls it
      where the value stands.
    - What it holds is a number, a bool, text, or another Array,
      Dictionary, enum with values or struct of them; anything else, as
      a pointer, is an error.
  - `x ?? d`, `if let some(v) = x { } else { }`, and what any enum with
    values has: `.is(c)`, `.some`, `.ok`, `.err`, `switch`.
  - kc's own `load` gives `Result<int64, String>`, and `case_named` an
    `int64?`.
  - **Chains** (#221), as kelvinc's of #218: `x?.m`, `x?.f(...)` and
    `x?[i]`, with the `?` right after `x`.
    - The rest of the chain is of a name kc binds to what `x` holds,
      `_kv_chainN`. The chain gives `some` of what the rest gives, or
      `none` where `x` is `none`.
    - An Optional the rest gives is not wrapped again, so `a?.b?.c` is
      a `T?`.
    - An owner the rest reads, as `p?.name`, is copied out. An `x` an
      expression gives, as `f()?.m` or `d[k]?.m`, is read once and
      freed.
    - A `T?` that only a chain needs is made while the functions are
      written, and written before them.
- **Overloading** (#234): functions of one name and different
  parameter types, as kelvinc's (#41).
  - A call gets the overload its arguments fit best, as kelvinc's `fit`
    scores them: the very type over a number, a `bool` among them, that
    converts; a text literal fits a `String`; `none` an Optional alone;
    a `T` a `T?` only where nothing else fits (#222).
  - A tie, and arguments no overload fits, are errors: C's function of
    the name is not called beside a Kelvin one (#223).
  - A prototype and its definition are one overload; a function
    declared and never defined is C's, and keeps its name.
  - In C each defined overload is named as kelvinc names it,
    `twice__i64`, `twice__String`, `show__vecp`, `kind__opt_i64`,
    `f__void`.
  - A call of a name that a variable hides is an error, where kelvinc's
    C would not compile.
- **Methods** (#213): `extend T { let m(...) ... static let f(...) ... }`
  and `let T.m(...)`; inside, `self`, `.x` for `self.x`, and `Self`.
  - `x.m(...)` is `T__m(x, ...)`, its receiver by value, and `T.f(...)`
    is `T__f(...)`: kelvinc's names, called straight, since kc sees the
    receiver's type where kelvinc lets C's `_Generic` choose.
  - `return {a, b}` is of the function's type.
- **C's names:** with a C header imported, a name kc does not know is
  C's, unchecked, as kelvinc has it: `strlen(s)`, `getenv(name)`,
  `nullptr`, a typedef as a type, `n:size_t`, and `:=` of a `cstr`.
- **Types:** `int64`, `int32`, `uint8`, `uint32`, `float64`, `float32`, `bool`,
  `cstr`, `String`, `IO`, `uchr`, a struct, `$[T]`, `T^`, main's
  `[cstr]`, and `Dictionary<K, V>` of `String` or integer keys (#211).
  - **`float64`** (#262): literals `1.5`, `2.5e-8`, and `nan`, `inf`
    and `infinity` in any case, where no variable has the name, as
    kelvinc's (#261); arithmetic, comparisons and `as` are C's; printed
    as kelvinc prints it, every digit with a point (#259).
  - **`float32`** (#263): C's `float`, of a literal, `let x:float32 =
    0.1`, or `as float32`, `nan as float32`; printed as kelvinc prints
    it, `0.100000001`.
- **`$[a, b]`** (#266), an Array of its elements: of their one type,
  as kelvinc's, or of the type written, `var fs:$[float64] = $[1, 2.5]`,
  each converted, text into a String, `{a, b}` into a struct.
  - Elements of more than one type are an error, as kelvinc's, and so
    is an owner a variable holds, which `=` would copy.
- **`${k: v}`** (#267), a Dictionary of its entries, set in order, a
  later key's value winning: of the first entry's types, a text key a
  String's, as kelvinc's, or of the type written, each converted.
  - Keys or values of more than one type are kelvinc's errors, `every
    value of a Dictionary has one type: this one is f64, the first
    i64`; so is a value that owns, held by a variable.
  - A String key an expression gives is held while it is copied in.
  - An Array's or a Dictionary's name in C is its element's as kelvinc
    mangles it, `_kv_dict_String_Dictionary_String_i64`, so they nest.
- **`x:T`** (#264) converts as `x as T` does, kelvinc's annotation:
  `0.1:float32`, `'z':uint8`, `c ? 1:int64 : 0`.
  - The `:` is one where a type's word follows, `int64` to `uchr`, and
    no `(` or `<`; else it is `?:`'s or a `case`'s.
  - A struct's name or a C typedef's too, `p:point`, `n:size_t` (#265),
    but in the middle of `c ? a : b` and in a case's values, where a
    name after `:` is `?:`'s or the case's, as kelvinc reads it; in
    parentheses or a call's arguments there, it is an annotation again.
- **Lets do not change** (#271), as kelvinc has it: assigning a let, `+=`
  to it, its member or element, `xs.pop()` or `d.remove(k)` of it, is
  kelvinc's error, word for word.
  - A let, `'x' is a let and cannot change; declare it with var`; a
    parameter, a let unless written `var n:T`, which kc takes now; a
    loop's element, an `if let`'s or a case's value; a range's count.
  - A change through a pointer, `p^ += 1`, is the pointee's, not the
    let's.
  - **`&x` of a let is a `const T^`** (#272), as kelvinc's, C's
    `const T *`: what it points to does not change, `p^ = 2` an error,
    and it goes where a `const T^` goes, not a `T^`.
    - Of an owner too, a String, an Array or a Dictionary, as kelvinc
      since #273; a function that reads one takes `const $[T]^`.
- **Statements:** `var` and `let`, with a type or one inferred (#214);
  `=`, `:=`, `+=` and the rest; `if`, `else if`, `else`; `while`;
  `for i in a..<b`; `for x in s` of a String or an Array, `for k, v in
  d` and `for k in d` of a Dictionary, in the order added (#269); `return`,
  `break`, `continue`.
  - **`=` and `:=`** (#233), as kelvinc has them: a reference, a `cstr`
    or a `T^`, takes `:=`, and a value `=`, in a declaration, a global's
    or an assignment; else kelvinc's error, as `'s' is a reference
    (cstr): assign it with ':=', not '='`.
  - An Array and a Dictionary are not checked, as kelvinc does not
    check them.
- **`switch`** (#210), as kelvinc has it (#63): `case a, b:` and
  `default:`; a case ends at the next, its own block, with a `break`
  where it does not jump; a switch on an enum names every enumerator or
  has `default:`, any other has `default:`.
- **Expressions:** numbers, characters, `"..."` and `$"..."`, `true`,
  `false`, calls, `.member`, `.method()`, `a[i]`, `&x`, `p^`, `x as T`,
  `{a, b}` of a struct, `$[]`, `${:}`,
  `! - * / % + - < <= > >= == != && ||`, and `c ? a : b` (#232).
  - `c ? a : b` binds the loosest and groups to the right; a `?` right
    after a value and before `.` or `[` is a chain's instead.
  - Its type is `a`'s, or `b`'s where `a` is a word, as `none`; each
    arm is read by the type that takes it, so `n % 2 == 0 ? n / 2 :
    none` is an `int64?`.
  - Of owners, as kelvinc's O12: two places are a place, read where
    they are and not copied by `=`; two values expressions give are a
    value; one of each is an error but where it is returned, which
    moves either out.
  - kc's own source chooses so in five places.
  - A `?` after a `?` in a string is written `\?`, as kelvinc writes
    it: Kelvin has no trigraphs (#220).
- **Of the prelude and IO:** `.count`, `.copy()`, `.cstr`, `.pop()`,
  `.uchr`, `.utf32`, `String(text)`, `String(n)` of a number or a
  `bool` (#212), `println`, `IO(path, mode)`,
  `.string`, `.write(&s)`, `.close()`, `.error`, `.status`,
  `IO.exec(args, mode)`.
- **Of a Dictionary** (#211): `d[k]!`, checked; `d[k] = v`, which sets
  the entry; `d.has(k)`, `d.get(k, default)`, `d.count`; `d.remove(k)`,
  which frees what the entry held and is `true` where it was there
  (#270).
  - A String key an expression gives, `d.has($"a")`, is held for the
    call (#270).
  - `d[k]` read whole is a `V?` (#219), as kelvinc's since #218: `some`
    of a copy of the entry's value, or `none` where the key is missing.
    - It goes where a `V?` goes: `let a = d[k]`, `d[k] ?? v`,
      `if let some(v) = d[k]`, an argument, a return.
    - Assigning, modifying or going into `d[k]` is the place, checked:
      `d[k] = v`, `d[k] += 1`, `d[k].m`, `d[k]!`.
    - kc makes the `V?` of each Dictionary's `V` as it reads the type,
      so that the enum is written before the code that uses it.
  - `x!` of an Optional is `x.some`.
  - An Optional where a value goes is an error that names `!` and `??`,
    as kelvinc's (#219).
  - `d[k]?.m` chains (#221).
- **Ownership:** a `String`, an `Array`, a `Dictionary`, an `IO` or an
  enum with an owning case is freed by C's `cleanup` attribute; `return
  x` of a local one moves it out; a global one is freed at exit by
  `_kv_free_globals`, as kelvinc frees them (#215).
  - One an expression gives, where it is only read, is held in a
    temporary and freed once the expression is done (#227), as
    kelvinc's of #187: `({ T _kv_tmpN = f(); use(_kv_tmpN); })`.
    - That is an argument a function does not take by value, as
      `println(String(n))`, a borrow of it, `&f()`, a member, an element
      or a method of it, either side of `==`, the source of `for x in`,
      and a statement that drops it.
    - A member or an element that owns is copied out of it, as kelvinc
      does; a pointer into it, as `String(n).cstr`, is an error that
      says to bind it.
    - One bound, assigned, appended, returned or given by value moves
      there instead.
  - A struct owns where a member does (#225), as `struct pet { name:
    String; tricks: $[String] }`: kc writes its `_kv_T_free`,
    `_kv_T_take` and `_kv_T_copy` as kelvinc does, so it is freed,
    moved out by `return`, held in an Array, and freed before `=` gives
    it a new value. A local owner in `{a, b}` is copied, `.copy()`.
  - An owner a function or a method takes by value moves in, and the
    function frees it (#226), as kelvinc's O5: the parameter is
    `_kv_x_in` in C, bound to a local `x` that is freed where the
    function ends, or moved out by `return x`.
    - A whole variable moves in by `_take`; one an expression gives, as
      `f($"x")`, goes in as it is; a member or an element is an error
      that says to pass a borrow or a copy.
  - `.copy()` copies any owner but an `IO`: a String, an Array, a
    Dictionary, a struct or an enum that owns (#226).
  - Each type's C comes once, after the types it holds by value: an
    Array's element before the Array, a struct's members before the
    struct, an enum's values before the enum (#225).
- **Each statement is one line,** but inside `( )` and `[ ]`.

## Difficulties in the way of self-hosting kelvinc

What kc met, and what a Kelvin kelvinc would meet, so that the next
steps can take them on one at a time.

### The size of the language

- **kelvinc is 17,700 lines of C** (parser.c alone 12,300), and kc's
  3,900 lines of Kelvin read a part of what kelvinc reads (#231).
- **Taken into the subset since #204:**
  - `switch` and enums (#210), and enums with values (#215);
  - `c ? a : b` (#232);
  - overloading (#234);
  - `Dictionary` (#211), and `d[k]` as an Optional (#219);
  - methods of `extend` and `let T.m` (#213);
  - type inference (#214);
  - Optional and Result (#217), `x!`, and chains (#221);
  - `#import <x.h> as C` (#207);
  - of ownership's rules (documents/ownership.md): a struct that owns
    (O7, #225), passing by value (O5, #226), temporaries (O11, #227),
    and `c ? a : b` of owners (O12, #232);
  - printing what kelvinc prints, `some(3)`, `{x: 1, y: 2}`, `[1, 2]`
    and `{"a": 1}` (#229, #230, #268).
- **Left out of the subset:**
  - the overloads of methods; and kelvinc's names of the functions of
    an imported Kelvin file, `f__i64` overloaded or not, so kc cannot
    link a module kelvinc builds of Kelvin;
  - comparing an Optional, `x == none` or `x == 3` (#79);
  - `try`, `Optional`'s `map` and the rest of its methods;
  - attributes, subscripts and operators of `extend`;
  - anonymous and nested functions, and function types;
  - templates, `"""` and `$/.../` with its check;
  - `Set`, `union` and `typealias`;
  - integers but `int64`, `int32`, `uint8` and `uint32`;
  - the bitwise operators, `++` and `--`;
  - `#inline C`, `--lib` and `.kh`;
  - `#line`;
  - and kelvinc's hundreds of messages.
- **There is no specification but kelvinc:** grammar.md is partial, and
  the 834 tests of tests/run.sh are the nearest thing. A Kelvin kelvinc
  would take passing them as its acceptance.

### A bug found on the way

- **C's order of evaluation leaks into Kelvin.** kelvinc writes
  `nodes[n].a = parse_expr()` as `(*_kv_array_node_at(&nodes, n)).a =
  parse_expr();`.
  - When `parse_expr` grows `nodes`, gcc has already taken the old
    element's address and writes into freed memory; clang happens not
    to.
  - kc's stage1 built by kelvinc with gcc lost three functions of kc.k
    this way.
  - kc's source sets children through `set_a(n, parse_expr())`, and kc's
    own C computes such a value before the place.
  - kelvinc does too since #205.

### libc, and C of our own

libc is allowed, as it is to any C program; C of our own is not.

- **libc takes these off the list,** since kc reads `#import <x.h> as C`
  (#207):
  - The environment: `getenv` reads `KELVIN_HOME`, `CC` and `TMPDIR`,
    beside `-m` and `-cc`.
  - A temporary file: `$TMPDIR/kc-<pid>.c`, by `getpid`, which `remove`
    takes away once `cc` is done.
  - Not yet used: `mkdtemp`, which writes its template in place, where a
    String's `.cstr` is `const`; `exit`, where returning from main does.
- **A name that is C's unchecked hides a slip:** with a C header
  imported, a Kelvin function called before it is written is taken for
  C's, so the C compiler, not kelvinc, says it is undeclared. kc's
  gen.k met it, and declares `decl_named` first.
- **What libc does not give:**
  - **The `$/.../` check:** kelvinc links runtime/regexp_parse.c, C of
    our own, to check a pattern while compiling. A Kelvin kelvinc needs
    that parser in Kelvin, or the `RegExp` module, whose engine is C of
    our own too.
  - **The runtime:** libkelvin, `<IO>` and `<OS>` are C of our own. A
    compiler of Kelvin uses them as any Kelvin program does; writing
    them in Kelvin is a self-hosting of its own, beyond the compiler's.
  - **No `.o` of its own:** kc writes C and needs `cc`, which is no C
    of ours. Writing objects would take a backend, an assembler and a
    linker of Kelvin's own.

### Writing a compiler in Kelvin

- **Methods cannot change `self`:**
  - the parser's state is in globals;
  - the readers of examples/lambda.k are functions of a `reader^`;
  - kc's methods, since #213, are queries: `types[y].owns()`,
    `nodes[s].jumps()`, and `node.leaf(kind, t)`, a function of the type.
- **No recursive types:** the tree is an Array of nodes linked by
  index, as in examples/ski.k.
- **Declared before use:** mutual recursion needs prototypes first, as
  `let parse_expr():int64` and `let gen_expr(n:int64)`.
- **Inference stops at arithmetic:** `var j = n - 1` is an error.
  - Since #214 kc infers as kelvinc does: a literal, `int64`, `uint8` of
    a character, `bool`, `String` of `$"..."`; a comparison; a cast; and
    what it sees of a name, a call, a member or an element.
  - `"text"` is a `cstr` by `:=`; an empty `$[]`, `${:}`, `{...}` and
    what only C sees still need a type.
  - kc's own variables of a literal, 34 of them, say no type now. The
    rest keep theirs: one of arithmetic must, and the others are left
    as written.
  - kc's `.count` is an `int64`, where kelvinc's is a `size_t`: a
    variable inferred from one differs in its C type.
- **Characters:**
  - a character literal is C's `int`, and a `uchr` is a struct;
  - a String cannot be indexed, `s[i]` being an error;
  - so the source is held as `$[uint32]`, four bytes a character.
- **No switch on text:** a keyword is found by a chain of `tok_is`.
  - The kinds of tokens, nodes and types are enums since #210, `tkind`,
    `nkind` and `ykind`, and gen.k switches on them.
  - An enum must come before the struct that holds one, in kelvinc.
- **Text:**
  - `+=` appends text, a `uchr` or `&s`;
  - a number's text is `String(n)` since #212, where kc wrote the digits
    itself; `.cstr` and templates live in buffers of their block.
- **Errors:**
  - kc sets a global `failed` and moves the parser's cursor to the end,
    so that every loop stops;
  - `Result` would carry them, at the price of every parser; kc's
    `load` gives one since #217, read by `if let err(why) = load(path)`.
- **Lines:**
  - a statement ends with its line, so a long condition is one long line;
  - `as` is a keyword, so nothing is named `as`.
- **Speed:**
  - Since #211, a function, a global, a struct, an enum or an
    enumerator is found by its name in a `Dictionary`, where kc walked
    every declaration.
  - A local is still found by walking the scope, and a keyword by
    comparing codepoints.
  - What the Dictionaries give is that a name costs the same however
    many declarations there are: at kc's own size, 3,900 lines, a
    compile of kc by kc takes about 12 ms (#231), where 2,200 lines
    took 7 at #211.

### The runtime is part of the language

- **The C must fit kelvin_prelude.h:**
  - kc writes `KV_ARRAY(...)`, `KV_STRING_APPEND`, `kv_io_*` and the
    `_kv_array_i64` names as kelvinc does;
  - GNU C's statement expressions and `cleanup` attribute;
  - written down since #208 in
    [documents/c-contract.md](../documents/c-contract.md), from
    kelvinc's output.
- **Modules:** a module built by kelvinc names its functions by their
  types. kc names an overload as kelvinc does since #234, but not yet
  every function of an imported file; `<IO>` works because its
  functions are C's.

## Next steps

Each of these is one change of its own:

1. Grow kc's subset, keeping the fixpoint, and rewrite kc in each new
   part as it comes, from the list of what is left out.
2. Run kc on the tests of tests/run.sh that fit the subset, to count how
   far it reads, and the programs kc builds under tests/asan.sh's
   counting allocator, which is done by hand so far.
