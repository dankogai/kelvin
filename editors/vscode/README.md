# Kelvin for VS Code

Syntax coloring for Kelvin (#190): a TextMate grammar, `source.kelvin`,
for `.k` and `.kh` files, and for ```` ```kelvin ```` blocks in Markdown.

## Install

VS Code loads an extension from its extensions folder, so a link to this
folder installs it, and a `git pull` updates it:

```sh
ln -s "$PWD/editors/vscode" ~/.vscode/extensions/dankogai.kelvin-lang-0.0.1
```

- Run it from the top of the repository, then reload VS Code, with
  "Developer: Reload Window".
- On Windows the folder is `%USERPROFILE%\.vscode\extensions`.
- To make a `.vsix` to share instead, `npx @vscode/vsce package` in this
  folder, then `code --install-extension kelvin-lang-0.0.1.vsix`.

## What it colors

- Keywords: `let`, `var`, `struct`, `extend`, `typealias`, `if`, `for`,
  `in`, `switch`, `try`, `as`, `static`, and the rest.
- Declarations: the name of a function, `let fib(...)`, of a method or
  an attribute, `let point.norm(...)`, of a subscript, `let T[]`, and of
  a type after `struct`, `union`, `enum`, `extend` and `typealias`.
- Types: `int8` to `uint128`, `i8` to `u128`, `float32`, `float64`,
  `bool`, `cstr`, `uchr`, `String`, `Bytes`, `Array`, `Dictionary`, `Set`,
  `Optional`, `Result`, `IO`, and the modules' `RegExp`, `Match` and `c64`.
- Text: `"..."` with its escapes, `"""..."""`, templates `` `a${x}b` ``
  with the code in `${...}` colored as code, `$"..."` and `` $`...` ``,
  characters `'c'`, and regular expressions `$/pattern/flags` with their
  classes, groups, quantifiers and escapes.
- Numbers, decimal, hex, binary and octal; `true`, `false`, `nullptr`,
  `none`; `self` and `Self`; `$0` and `$[k]`; `$(...)`.
- Operators, among them Kelvin's own: `^` of a pointer, `:=`, `??`, `..<`
  and `...`.
- Comments, `//` and `/* */`, which the editor's toggle uses too.

## Test

`make test` runs `tests/grammar.js` where `node` is installed: every
regular expression compiles, every Kelvin file and document example of
the repository tokenizes with nothing left open, and sample lines get
their scopes.
