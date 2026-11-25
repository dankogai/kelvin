# TODO

What is left, checked against the code after #675; done since #657: the
crash of a struct that holds itself (#659); and the wrong message of a
cstr's byte set, which was none: `let s = "abc"` is the error there, as
text is declared with `:=`, and `s[0] = 65` of `let s := "abc"` says a
cstr is immutable (#660); a constant index past a fixed array's end,
kelvinc's error (#661); an integer divided by a constant 0, kelvinc's
error (#662); a literal that does not fit its type, kelvinc's error
(#663); a constant shift past its type's width, kelvinc's error (#665);
the reviews of P662 to P764 (#664, #666, #670, #673 to #675, #679, #691, #709, #723, #731, #735, #739, #745, #751, #759); and a member of arithmetic
whose type is C's, `(n + 1).foo` of a `u8`, which is kelvinc's `i32 has
no member 'foo'`, where it was C's error (#669); and an integer literal
past u64's greatest, or past i64's in a declaration with no type,
kelvinc's error (#678); and kc's top-level let of a pointer, a const
pointer as kelvinc writes it, `const uint8_t *const p`, where kc wrote
`const const uint8_t *` and `const int64_t *`, which C refused `q^ = 5`
of (#680). Added since #657, each
leaving every program as it was: `#import <Prime>`, with a computed
attribute of an integer type (#668); `_` among a literal's digits
(#671); and `BigInt.generatePrime(bits)` (#672). Each item becomes a
numbered change of Design.md when it is ordered; this list says what is
known, not what is planned.

## Versions

- So long as the grammar and the semantics stay the same, the version
  stays 0.4.x.
  - A fix, an error in Kelvin's words where C's came, a document, and
    kc reading more of what kelvinc reads are 0.4.x.
  - An addition that leaves every program as it was is 0.4.x too, as
    the user chose for an integer type's computed attribute (#668) and
    for `_` among a literal's digits (#671).
  - A change of what a program means, or of what it must write, is
    0.5.0.
- Release chores are done only when ordered.
  - 0.4.1's are done, the user's order after #745, ready for 0.4.1
    (#750): the CHANGELOG entry, #651 to #749; kelvinc's
    KELVIN_VERSION and the VS Code package's; Design.md's status; the
    README's line of the release notes; and, on the user's word after
    it, the tag v0.4.1 and the release Kelvin 0.4.1.
  - The next CHANGELOG entry is from #751 on: #751 to #763 so far.
  - The version: kelvinc's KELVIN_VERSION and the VS Code package's.
  - The README's line of the release notes.
  - The tag and the release.

## Faults in kelvinc

- The user's order after #759, resolve kelvinc then kc, of what was
  left listed, with the answers, each pushed when clean:
  - a number where a pointer goes, `var p:i64^ := 5`, `first(5)`,
    `[5]` of a `[i64^](1)`, a bool too, is `'p' is an i64^, and this
    is a number` in each place a value goes, in both, where it was
    C's error; `0` is C's null still, the user's answer, refuse any
    but 0 (#760);
  - a number, a bool, a struct, a union, an enum and a fixed array
    declared with no value in a function are zero, as kc writes them
    and as a pointer is nowhere, the user's answer, zero them in
    kelvinc, where kelvinc left them unset as C does; an array of a
    count C computes and a v.type by `memset` (#761);
  - `var v:[i64]`, an array of no count and no value in a function,
    is `[i64] takes its count from its elements: write [i64](N), or
    the elements`, kc's sentence, where it was C's error (#762);
  - `s -= x` of a Set, an Array or a Dictionary is an error that names
    `.remove`, the user's answer, `a Set has no '-=': remove an
    element with s.remove(x)`, and any other operator but `+=` of
    them `a Set has no '*='`, in both, where it was C's error and
    kc's an owner is assigned only as a String; kc says kelvinc's `a
    Dictionary has no '+='` too (#763).
  With it kelvinc's four are done.

- The user's order after #751, resolve kelvinc then kc, of the
  differences found while #746 to #749 were made, each pushed when
  clean, the version 0.4.1 still:
  - a fixed array's element and a Dictionary literal's value of
    another kind, where the type is written, are kelvinc's errors in
    kc's sentences, `an element of [i64](2) is an i64, and this is
    text` and `a value of Dictionary<String, i64> is an i64, and this
    is text`, where they were C's, a struct's element built with a
    number (#752);
  - `let h := apply` of a function that takes an
    `f:([[i64](n)](2)):i64`, and `let g := grid` of one that takes an
    `m:[[i64](n)](2)`, are built, the row written with no count in a
    function type, `T (*)[]`, where C found no `n` in the variable's
    type; kc, which built the first, builds the second so (#753).
  With it kelvinc's two are done.
  - a container of structs is named by the struct's bare name,
    `Array<point>` and `Dictionary<String, point>`, by `.typename` and
    in kelvinc's errors, as kc names it, where kelvinc said
    `Array<struct point>`; found while #752 was made, and of the same
    order (#758).

- The user's order after #745, resolve kelvinc's listed faults, then
  kc's, each pushed when clean, then the chores of 0.4.1 short of the
  tag:
  - a literal's element read through const, `$[q[0]]` of a `q:const
    i64^`, `${"k": q[0]}`, `[q[0], q[0]]` and `$[p]` of a `p:i64^
    const`, is of the plain type, as a variable inferred of it is
    since #738, where C warned or refused and the fixed array's
    elements were const; a volatile's too, in kc as well (#746);
  - `apply.typename` of a function that takes an
    `f:([[i64](n)](2)):i64`, which was `?`, and with it the name of
    every type of a count C computes, `[i32](n)`, a `b:a.type`'s too,
    the user's answer, as a's (#747);
  - a function of rows of another type given to such a parameter,
    C's error, and with it every value where a function type goes: a
    function of another type, `this is (f64):i64, where (i64):i64
    goes`, kc's sentence, and a value that is no function, of which C
    took text and a pointer; member_value's clause that is never
    false is gone with it (#748).
  With it kelvinc's listed faults are done.
- The user's order after #731, the three faults of kelvinc's found
  while #724 to #730 were made, one number each, pushed when clean:
  - a compound literal's commas where a macro's argument goes,
    `println(sizeof ([i32](3))[1, 2, 3])`, which was C's error of
    kelvinc's C, and of kc's: the argument in parentheses (#732);
  - an element changed through a `[const i64](3)^`, C's error of
    kelvinc's C, and with it every element of a `[const T](N)` and
    `p[i] = v` through a `const T^`: errors in Kelvin's words (#733);
  - a global whose value needs a struct written after a function that
    names the global: the struct is moved up with the global (#734).
  With it the three are done.
- None known: an integer literal past u64's greatest is kelvinc's error,
  and so is one past i64's in a declaration with no type (#678), found
  while literals.md was written (#677).
- A member of arithmetic, `(n + 1).foo`, is kelvinc's error (#669).
- The sweep's three that C only warned of are kelvinc's errors (#661 to
  #663), and so is a constant shift past its width (#665).

## kc

- The user's order after #751, kc's differences found while #746 to
  #753 were made, after kelvinc's two (#752, #753), each batch pushed
  when clean:
  - a function whose parameter is a fixed array is a value of its type
    as written, `([i64](3)):i64`, `([[i64](3)](2)):i64` and
    `([const i64](3)):i64`, as kelvinc names it, where kc named the
    array's pointer; and it goes where a function type that is the
    same in C goes, `take3(three)`, the array's pointer, an array of
    no count and rows behind a pointer too, an anonymous function's
    alike, where kc said no function of the name is of the type (#754);
  - `:=` of an Array, a Dictionary or a Set is an error in both, `'d'
    is a value (Array<i64>): assign it with '=', not ':='`, at a
    declaration too, the user's answer, a value: refuse := everywhere,
    where kelvinc could not tell and built `a := b`, which freed one
    twice, and kc refused it after the declaration in its own words;
    kc says the rule of an element and of `p^` too, `this target is a
    value (i64)`, which it built (#755). tests/run's
    set_declared_reference.k, #749's, is tests/error's.
  - three that kc did not read (#756): a `w:v.type` of an array of a
    count C computes, read as the array, its `.count`, its elements, a
    walk and its text; an array of a constant count with no value,
    `var a:[i64](sizeof(i64))`, `[i64](K)` and `[i64](2 * 4)`; and a
    struct's braces whose first value is an Array, `{$[1], 2}`.
  - sentences and places that were kc's own or C's (#757): a Set's
    element of another kind, in a literal of a written type, `s += v`,
    insert, has and remove, `a key of Set<i64> is an integer`; an
    Array's `+=`, append and insert of another kind, `an element of
    Array<i64> is an i64, and this is text`, a function's too; an
    element and a value where an Optional goes, by its case; a
    designated element's value; a value that is a member read, said at
    its `.`; and a member that is no owner where an owner's parameter
    goes, said by its kind.
  - left, each listed under its "Found while": a function of two types
    inside a function named `_kv_main_t1` in an error, and a
    function's name as an element there; `Set([q[0]])`; `{$[1]}` of a
    struct of one Array; a Dictionary in a Dictionary's literal;
    `[v.type](2)`; `nowhere` where an i64 goes; `a += { $0 + 1 }`,
    which kelvinc refuses and kc builds; `s -= "a"` of a Set.

- The user's order after #745, kc's two listed differences, after
  kelvinc's faults (#746 to #748), pushed when clean (#749):
  - a cstr variable where a String goes, `var t:String = s`, is
    kelvinc's `'t' is a String, and this is cstr`, where it was C's
    error of kc's C: a declaration, an assignment, a parameter, a
    member, an Array's element, a `return`, and an Optional's and a
    Result's case, `case 'some' of String? holds a String, and this is
    cstr`, a template that is a cstr too;
  - `var d := ${"a"}` declares a Set, as kelvinc takes it, as an
    Array's and a Dictionary's.
  With it both are done; what was found on the way is listed below.

- kc says each of the 1102 programs kelvinc refuses in kelvinc's words:
  the 990 of #652 to #656, and those of #659 to #678, #702, #705, #724,
  #725, #727, #733, #736, #740, #741, #742, #743, #744, #748, #749,
  #752, #754, #755, #757, #760, #762 and #763 alike.
- kc places each of those errors at kelvinc's line and column, matched
  in batches as the user ordered after #680 (#681 to #689), and
  selfhost/errors.sh compares them (#690), but one, listed in
  selfhost/errors.txt as `place`: anon_list_c_arg, {'a', 'b', 'c'}
  given to a C function, which kelvinc says at its second comma, where
  its parse of an anonymous function ends.
- kc prints a struct's members of no printer of their own by their text,
  a pointer, a function, an IO, a plain enum and a C header's type, as
  kelvinc's (#692), where it said "not yet what this holds".
- kc shows a fixed array in a template and by `.pretty`, and a let
  parameter's by its count as declared, a parameter's `[T]` by its
  address, as kelvinc's (#693).
- kc reads a top-level enum with no name whose cases have values, its
  spelling's type, its cases words of the program (#120), and the
  methods of a type with no tag (#121), as kelvinc's (#694).
- kc reads overloads of a variadic function, `f__T__va`, chosen as
  kelvinc chooses, C's choice falling back to the one whose `...` takes
  the value (#695).
- kc reads `typeof` of an expression and `x.type` where `x`'s type is
  inferred or only C sees, written `__typeof__(x)` as kelvinc writes it,
  and `(T){...}` of such a type (#696).
- kc reads a function defined inside a function, `_kv_outer_name` in C,
  its block's, as kelvinc's #180 (#697).
- kc walks a pointer up to a 0, from nowhere none, and what only C sees
  so, as kelvinc's #30 and #610, and takes nowhere among a `[cstr]`'s
  elements (#698).
- kc reads `[T?](n)`, a fixed array of Optionals, and prints a fixed
  array of a count C computes, `[f64](n)`, as kelvinc's (#699).
- kc gives a global C cannot initialize its value at its first use, once,
  by `pthread_once`, as kelvinc's #493, so a value's text is made in a
  global's initializer too (#700).
- kc reads `T^ atomic`, the pointer itself C's `_Atomic`, `T *_Atomic`,
  as kelvinc's #642 (#701).
- An enum, a struct or a union with no name in a block or inside a type
  is kelvinc's error, which kc says in its words where it said "not
  yet" or its own, with two tests of tests/error (#702).
- kc reads a parameter's array of arrays whose inner count C computes,
  `m:[[i64](n)](2)`, as kelvinc's (#703).
- kc takes none and a value some(v) is made of among a fixed array of
  Optionals' elements, `([i64?](2))[none, 1]`, as kelvinc's (#704).
- A Dictionary's key, a Set's element and a fixed array where an
  element goes are checked where the type is written, kelvinc's errors
  at its place, where kc built `Set<f64>` and said the rest at the
  variable, with three tests of tests/error (#705).
- kc prints a choice of bools, `a < b ? a > 0 : b > 9`, as a bool,
  where C's ?: of them gave an int, 1 (#706).
- kc writes a record's text as kelvinc's, `_kv_T_cstr` to its own
  longest, for `.cstr` and a template, an Array member `[...]` (#707).
- kc keeps a let's const in `typeof(k)`, `const i64`, as kelvinc's
  (#708).
- kc reads `x as T ? a : b` as a choice, as kelvinc's, where it read
  `T?`, and holds `&$"b"` given to a search, so that SION.k and the
  tests that import it build (#710).
- kc reads `Optional<T>()` and `Optional<T>(v)`, a typed none and
  some(v), and moves an owner into a `T?` parameter as some of it, as
  kelvinc's (#711).
- kc makes an Optional's and a Result's `.map`, `.flatMap` and
  `.mapErr`, as kelvinc's #80 and #81 (#712).
- kc makes a Bytes's `.toBase64()`, `Bytes.fromBase64(text)`, its slice
  `b[lo..<hi]` and `b + c`, as kelvinc's (#713).
- kc takes an empty last case, `default:`, `p[i] = v` through a let
  pointer parameter, `IO.strerror(code)` and `(shape){.rect = ...}` of
  an enum with values, as kelvinc's (#714).
- kc reads an operator at a line's end, `$"a" "b"`, labels and goto,
  `[[2] = 9]`, `(T){` in a condition as kelvinc tells it, a comma in a
  condition, a method's prototype and `var a = 1, b = 2` of globals, as
  kelvinc's (#715).
- kc appends to an Array `&ys`'s elements, an Array an expression gives,
  what `&p` points to and text as a String, and reads `xs.capacity`, as
  kelvinc's (#716).
- kc reads `let s:[u8] = "hi"`, `[[T]]` of rows, `let ap := arr` of an
  array and infers C's `size_t` from sizeof, `.size`, `.align` and a
  count, as kelvinc's (#717).
- kc reads `v.pretty(n)`, `cstr restrict`, `$(...)` in a function of a
  type and an anonymous function's `:()`, as kelvinc's (#718).
- kc reads a list of initializers that hold functions, `$(...)` in an
  anonymous function, a `?:` across lines and `f as (i64) : g`, a call
  in a top-level struct's count and an anonymous function's array
  parameters, as kelvinc's (#719).
- kc reads `((i64):i64)^`, arrays of functions, a file imported again
  by another path, a header next to an imported file and `{.s = v}`
  where a variable `s` hides the case, as kelvinc's (#720).
- kc reads `.pretty` of an enum with values, `async` of a function
  value and a number's text in a brace-less for body, as kelvinc's
  (#721).
- kc writes a let's local array with C's `const`, `const int32_t
  a[2]`, and says a list where no array is declared in kelvinc's words,
  `'[...]' initializes an array, and this is Array<i64>: write a
  value`, the two differences found while #717 was made (#724).
- The user's order after #735, kc's small differences, those found
  while #724 to #733 were made, in batches, each pushed when clean:
  - the words of errors (#736): an array where a value goes named by
    its pointer, `i64^`; braces assigned to a member, an element and
    `p^`; `ok({1, 2})`; a method a fixed array has not; a row where a
    number goes;
  - zeros where a pointer goes, `var p:i64^ := [i64](3)`, and a
    pointer to an array of a count C computes, `[i64](n)^` (#737);
  - the names of `q[1]` through a `const i64^`, `[cstr const](2)` and
    `const i64^ const^`, and a fault of kelvinc's found there: a
    variable inferred from a read through const was const itself, and
    is the plain type, the user's answer (#738);
  - left then, each C's error in kelvinc, which kc said in Kelvin's
    words or built, six: the user's order after #739, below.
- The user's order after #739, the six left to C, with the answers of
  their words, each pushed when clean:
  - a call through a function value of the wrong count, `f(1)` of an
    `f:(i64, i64):i64` and `v()` of a variadic one: kc's sentence,
    kelvinc's too, `this function, of type (i64, i64):i64, takes 2
    arguments, and it is given 1`, `or more` of a variadic one (#740);
  - a struct's member given the wrong kind of initializer, as a
    parameter's, `'y' of pt is an i64, and this is text`, an array
    member's and `var a:[i64](3) = 5` too (#741);
  - `T^ const` and `cstr const`, a pointer that is itself const, read
    and named by both, `p := &y`, `p += 1` and a member's `h.p := &y`
    of one `'p' is an i64^ const, a pointer that does not change:
    declare it without const to point it elsewhere` (#742);
  - `ok({})` and `err({})`, the list error of `ok({1, 2})` in both,
    where kelvinc said the case holds a T, and this is (), and kc
    built it or left it to C (#743);
  - `while (i == 0) (i) += 1`, kc's as kelvinc's, `assignment is a
    statement in Kelvin, not a value`; and a function type's parameter
    of an inner count another parameter gives, `f:([[i64](n)](2)):i64`,
    whose typedef kc wrote with `n` and writes with no count, `T
    (*)[]` (#744);
  - left: none of the six.
- Found while #724 was made:
  - `var o:i64? = [i64](3)` is kelvinc's `case 'some' of i64? holds an
    i64, and this is i64^`, and kc's too since #736.
  - `var p:i64^ := [i64](3)`, zeros where a pointer goes, is kelvinc's
    zeroed compound literal, `(int64_t [3]){0}`, and kc's too since
    #737.
  - A type name that is not known, `let j:JSON = 1` with no import, is
    C's error of each one's C, `unknown type name 'JSON'` of kelvinc's
    and, where kc's C differs, another of kc's: no error of Kelvin's in
    either (#736 looked).
- Places where kc reads not yet what kelvinc reads, 29 as counted after
  #675, ordered taught in batches after #691:
  - `(T?){}`, which kelvinc built as `some(0)` and kc refused, is none
    in both, the user's answer after #723 (#725); a fixed array in
    another type is kelvinc's error too, said alike since #705;
  - the number of a prelude enum's word that only C gives, which no
    enum of the prelude has, so no program reaches it.
- kc's output that differed from kelvinc's, found while #692 to #696
  were made, is kelvinc's, the user's order after #705 (#706 to #708).
- kc takes and gives owners through function values, as kelvinc's
  (#722).
- kc builds and prints what kelvinc's prints of all 513 programs of
  tests/run and examples, the quines as run.sh compares them, as of
  #738.
  The 49 that stopped on errors of kc's own, which the user ordered
  taught in batches after #709, are taught, #710 to #722.
- Found while #725 was made, kc's too since #736:
  - Braces assigned to a member, an element or through a pointer,
    `p.x = {1}`, `a[0] = {3}`, `h^ = {3, 4}`, are kelvinc's `a list is
    not a value here: ...`.
  - `ok({1, 2})` where a `Result<pt, i64>` goes is kelvinc's error.
- Found while #726 was made, not changed:
  - `r[1][2] = 5` through a `[const i64](3)^` was C's error of
    kelvinc's C, and kc's `this changes an element of a [const
    i64](3)`: kelvinc's words too since #733.
  - A pointer to an array of a count C computes, `[i64](n)^`, is
    kelvinc's, and kc's too since #737.
  - `q[1].typename` through a `const i64^` is kelvinc's `const i64`,
    and a cstr's `s[1]` `const u8`: kc's too since #738.
  - A method a fixed array has not, `r[1].sum()`, is kelvinc's
    `[i64](3) has no member 'sum'`, and kc's too since #736.
- Found while #763 was made, not changed:
  - `t -= "a"` and `t *= 2` of a String, and `b -= 1` of a Bytes, are
    C's errors of kelvinc's C and kc's `an owner is assigned only as a
    String`.
- Found while #758 was made, not changed:
  - `a := $[]` of an Array is kelvinc's `'a' is a value (Array<pt>)`
    and kc's `Array([]) has no element type`.
- Found while #757 was made, not changed:
  - `a += { $0 + 1 }` of an Array of functions is kelvinc's `a list is
    not a value here` and built by kc.
  - `s -= "a"` of a Set was C's error of kelvinc's C and kc's `an owner
    is assigned only as a String`: `a Set has no '-='` in both since
    #763.
- Found while #756 was made, not changed:
  - `{$[1]}`, one value and no comma, of a struct of one Array is its
    value by kelvinc, which knows the struct, and `$0` by kc.
  - `var v:[i64]`, no count and no value, was C's error of kelvinc's C
    and kc's `[i64] takes its count from its elements`: kc's sentence
    in both since #762.
- Found while #755 was made, not changed:
  - `{$[1], 2}` of a struct whose first member is an Array is built by
    kelvinc and was kc's `'$0' is a parameter of an anonymous
    function`: built by both since #756.
- Found while #753 was made, not changed:
  - `h(3, corners)` in a function whose `h` is a parameter of the type
    `(i64, ([[i64](3)](2)):i64):i64` was refused by kc, `no function
    'corners' is ([[i64](3)](2)):i64`, of a function's fixed array
    parameter: built since #754.
- Found while #752 was made, not changed:
  - A container of structs was named with `struct` by kelvinc,
    `Array<struct pt>` and `Dictionary<String, struct pt>`, by
    `.typename` and in its errors, and `Array<pt>` by kc: `Array<pt>`
    by both since #758.
  - A number where a pointer goes as an element or a value, `[5]` of a
    `[i64^](1)` and `${"a": 5}` of a `${String: i64^}`, was C's error
    of kelvinc's C; of the second kc said `a value of ... is an i64^,
    and this is a number`: said so in both, of any number but 0,
    since #760.
  - An element or a value where an Optional goes is kelvinc's `case
    'some' of i64? holds an i64, and this is text`, and was kc's `an
    element of [i64?](1) is an i64?, and this is text`: kelvinc's in
    both since #757.
  - A designated element, `[[1] = "a"]`, is kelvinc's error and was
    C's of kc's C; a Set's element of another kind, `${"a"}` of a
    `${i64}`, is kelvinc's `a key of Set<i64> is an integer` and was
    C's of kc's C: kelvinc's in both since #757.
  - A Dictionary in a Dictionary's literal of another value's kind is
    said of the inner one by kelvinc and of the outer by kc.
  - `nowhere` where an i64 value goes is C's error of kelvinc's C and
    kc's `this is a type only C sees`.
  - A function's name of another type as an element, of a function
    defined inside a function, is kelvinc's `no function 'half' is
    (i64):i64` and kc's element sentence.
- Found while #749 was made, not changed:
  - `d := ${2}` and `a := $[2]`, an owner assigned by `:=` after its
    declaration, were built by kelvinc and kc's `an owner is assigned
    only as a String`: `'d' is a value (Set<i64>)` in both since #755.
  - A cstr variable as a Dictionary literal's value, `${"k": s}` of a
    `${String: String}`, is C's error of kelvinc's C and kc's `a value
    of Dictionary<String, String> is a String, and this is cstr`.
- Found while #748 was made, not changed:
  - A fixed array's element and a Dictionary literal's value of
    another kind are C's errors of kelvinc's C, `var fs:[i64](1) =
    ["a"]` and `${"a": "x"}` of a `${String: i64}`, a function's too,
    and kc's `an element of [i64](1) is an i64, and this is text`.
  - `a += "x"` of a `$[i64]` is kelvinc's `an element of Array<i64>
    is an i64, and this is text`, and was C's error of kc's C; `a +=
    5` of a `$[(i64):i64]` is kelvinc's element sentence and was kc's
    `this is i64, where (i64):i64 goes`: kelvinc's in both since #757.
  - A member where a function goes, `num(o.n)`, is said at the `.` by
    kelvinc and was said at the member's name by kc: at the `.` in
    both since #757.
  - A function of a pointer to a row, `{ (m:[i64](3)^):i64 in ... }`,
    where rows of a count C computes go is built by kelvinc and was
    refused by kc: built since #754.
  - A function of two types defined inside a function, `t`, given
    where neither goes is said of `_kv_main_t1` by kc.
- Found while #747 was made, not changed:
  - A function's parameter that is a fixed array is named as written
    by kelvinc, `g3.typename` of a `g3(m:[[i64](3)](2))`
    `([[i64](3)](2)):i64`, and was named as its pointer by kc,
    `([i64](3)^):i64`; `let f:([[i64](3)](2)):i64 := g3` is built by
    kelvinc and was refused by kc: as kelvinc's in both since #754.
  - `let h := apply` of a function that takes an
    `f:([[i64](n)](2)):i64` was C's error of kelvinc's C, `n` in the
    variable's type, and built by kc: built by both since #753.
  - `w.count` of a `w:v.type` whose `v` is a `[i64](n)` was kc's `this
    member is not known`, and 3 by kelvinc: 3 by both since #756.
  - `var w:[v.type](2)` of such a `v` is `?` by kelvinc's `.typename`
    and kc's "not yet".
  - `var v:[i64](sizeof(i64))` is built by kelvinc and was refused by
    kc, `[i64](...) takes its count from its elements`: built by both
    since #756.
- Found while #746 was made:
  - `var d = v` of a `v:volatile i64` was an `i64` by kelvinc and a
    `volatile i64` by kc: an `i64` in both since #746.
  - selfhost/README.md's line of #741's tests stood after #744's,
    where #742's lines were written into #741's: put back by #746,
    which the review #745 had not seen.
  - `var d = Set([q[0]])` is kelvinc's `expected an expression, found
    'Set'`, and kc's `'d' needs a type`: not changed.
- Found while #745, the review, was made:
  - parser.c's member_value asked, of a pointer member, `!(w->kind ==
    T_BASE && ...)` after `w->kind == T_PTR`, a clause that is never
    false: gone since #748.
- Found while #744 was made, not changed:
  - `apply.typename` of a function that takes an
    `f:([[i64](n)](2)):i64` was `?` by kelvinc, and `(i64,
    ([[i64](n)](2)):i64):i64` by kc: kelvinc's too since #747.
  - A function of rows of another type given to it, `{
    (m:[[f64](3)](2)):i64 in 1 }`, was C's error of kelvinc's C, and
    kc's `this is ([f64](3)^):i64, where ([[i64](n)](2)):i64 goes`:
    kelvinc's `this is ([[f64](3)](2)):i64, where ...` since #748, the
    array named as written, where kc names its pointer.
  - A function of rows of four given where `n` is 3 is built by both,
    as C takes a row of any count there.
- Found while #743 was made, not changed:
  - `Result<T, U>.ok({})` and `.ok({1, 2})`, the case by the type's
    name, are built by both, the braces its value's initializer.
  - `ok({ n += 1 })` where a `Result<(), i64>` goes is kelvinc's `a
    Result of a function type has no spelling yet`, said of the type,
    and kc's `expected an expression, found '+='`.
- Found while #742 was made, not changed:
  - A literal's element read through const kept the const in
    kelvinc: `$[q[0]]` of a `q:const i64^` and `$[p]` of a `p:i64^
    const` were C's warning, `${"k": q[0]}` C's error, and
    `[q[0], q[0]]` a `[const i64](2)`; kc held the plain type, as a
    variable inferred of one is since #738, and kelvinc does since
    #746.
  - `var t:String = s` of a cstr variable is kelvinc's `'t' is a
    String, and this is cstr`, and was C's error of kc's C: kc's too
    since #749.
  - `var d := ${"a"}`, a Set of text given by `:=`, was built by
    kelvinc and refused by kc, `'d' is a value (Set<String>)`: built
    by both since #749, and refused by both since #755, a Set a value.
- Found while #741 was made, not changed:
  - A number given to a `cstr` parameter of a function defined inside
    a function, `take(5)`, is kelvinc's `'c' of 'take' is a cstr, and
    this is a number`, and C's error of kc's C; of a top-level function
    kc says it.
  - C's brace elision, `{1, 7, 8, 9}` for a number and an array of
    three, is refused by both since #741, the array's `[...]` asked.
- Found while #740 was made, not changed:
  - `let t:() := { println("t") }`, an anonymous function of no
    parameter and no result where `()` goes, is kelvinc's, and kc's
    `this is no function, where () goes`.
- Found while #738 was made, not changed:
  - `typeof(k)` where an expression goes is kelvinc's `expected an
    expression, found 'typeof'`, and C's error of kc's C.
- Found while #737 was made, not changed:
  - Zeros of a count C computes where a pointer goes, `var q:i64^ :=
    [i64](n)`, are C's error of both, `compound literal cannot be of
    variable-length array type`.
  - `let r:[i64](n)^ := &v` of a `v:[f64](n)`, and a let's row given
    to a `[i64](2)^` that may change it, are kc's errors, in Kelvin's
    words, where kelvinc's C warns, as #362 has it.
- Found while #736 was made, not changed:
  - `ok({})` where a `Result<pt, i64>` goes was kelvinc's `case 'ok' of
    Result<pt, i64> holds a pt, and this is ()`, and kc's build: `a
    list is not a value here` in both since #743.
  - `var p:Nope^ := nowhere` of a name that is no type is C's error of
    both.
- Found while #733 was made, not changed:
  - `[const cstr](2)` is named `[cstr const](2)` by kelvinc's
    `.typename`, and a pointer to a const pointer `const i64^ const^`:
    kc's too since #738.
  - `var c:[i64](2)` with no value was not zeroed by kelvinc, and is by
    kc: zeroed by both since #761.
- Found while #730 was made, not changed:
  - A number where a struct's array member goes, `{1, [7, 8, 9], 5}`
    of a `name:[u8](8)`, was left to C by kelvinc, which built it:
    `'name' of bag is a [u8](8), and this is a number` in both since
    #741.
  - Text longer than a struct's `[u8](N)` member is C's in both: the
    member filled, with no NUL.
  - A function's parameter of a function type whose own parameter's
    inner array counts by another parameter, `f:([[i64](n)](2)):i64`,
    is built by kelvinc; kc wrote `n` into the type's typedef, C's
    error, and builds it since #744.
- Found while #729 was made, not changed:
  - `v()` of a `v:(i32, ...):i64`, fewer arguments than its
    parameters, was C's error of kelvinc's C: `this function, of type
    (i32, ...):i64, takes 1 argument or more, and it is given 0` in
    both since #740.
  - `var q:cstr const := name` is kelvinc's `const uint8_t *const q`;
    kc read the const and wrote none, so that `q := other` was C's to
    kelvinc and built by kc: `'q' is a cstr const, a pointer that does
    not change` in both since #742, kc writing the const.
  - `volatile` of a struct, and `const volatile` of what is no pointer,
    are read by kc as kelvinc reads them, and tried by no test.
- Found while #727 was made, not changed:
  - A struct written before an `#inline C` that holds one of its types
    is C's error in both; a function written before it that takes a
    struct written after it, which holds its type, is kelvinc's C's
    error, and kc's build.
  - `while (i == 0) (i) += 1` is kelvinc's `assignment is a statement
    in Kelvin, not a value`, and kc's `expected '{': the body of
    'while' is a block`.
- The user's order after #723, go on with them all, each pushed when
  its battery is clean:
  - the two differences found while #717 was made (#724);
  - `(T?){}` and `x:T? = {}`, none in both compilers, as an Optional
    declared with no value, the user's answer (#725);
  - `q[i]` of a `q:[T](N)^`, read by kc as kelvinc reads it, the user's
    answer, where kc said its own error of #362 (#726);
  - the 30 programs kc does not build, in batches, `#inline C` passed
    through to C among them:
    - `#inline C` (#727): inline_c, inline_c_fn, inline_c_hash,
      no_trigraphs, stmt_macros;
    - lines that go on and five forms beside them (#728):
      semicolons_edge, semicolons_more, pointer_step, methods_edge,
      order_free, tag_names_edge;
    - C's types and values (#729): casts_edge, casts_edge2,
      casts_edge3, cstr, text_numbers, text_numbers_more,
      function_types, nowhere, is_null, addr, properties_c;
    - the last eight (#730): io_process, io_kill, io_signal,
      coalesce_text, anonymous_edge, array_types, anonymous_values,
      local_storage; with them all 30 are built, the order done.
- Self-hosting's mid goal, no C emission, has no number yet.

## Provisional rows

- P765 to P768, the details of #760 to #763, until reviewed; the reviews confirmed
  every row to P764, and a review's own detail row is confirmed by that
  review (#675).

## Open design

- Closures and protocols: neither is in 0.4.0, and protocols come first
  when one is taken up.
- `long double` and `f128` have no Kelvin spelling yet.
- Safe primes of `<Prime>`, a prime p with (p - 1) / 2 prime, as
  OpenSSL's `BN_generate_prime_ex` makes with `safe`: not now, as the
  user answered for #672.
