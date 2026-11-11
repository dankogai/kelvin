// A quine: a program that prints its own source, these comments too.
// s is the whole program, with one mark where s itself goes, the
// codepoint 64; printing s, the mark is s again, written as the literal
// it is here: in quotes, with its quotes, backslashes and newlines
// escaped. No other character of s is the mark, so it is printed once.
// quine: prints its own source
let main():i32 {
    let s = $"// A quine: a program that prints its own source, these comments too.\n// s is the whole program, with one mark where s itself goes, the\n// codepoint 64; printing s, the mark is s again, written as the literal\n// it is here: in quotes, with its quotes, backslashes and newlines\n// escaped. No other character of s is the mark, so it is printed once.\n// quine: prints its own source\nlet main():i32 {\n    let s = @\n    for c in s.codepoints {\n        if c.utf32 != 64 {\n            print(c)\n            continue\n        }\n        print(\"$\\\"\")\n        for d in s {\n            if d == '\"' {\n                print(\"\\\\\\\"\")\n            } else if d == '\\\\' {\n                print(\"\\\\\\\\\")\n            } else if d == '\\n' {\n                print(\"\\\\n\")\n            } else {\n                print(d)\n            }\n        }\n        print(\"\\\"\")\n    }\n    return 0\n}\n"
    for c in s.codepoints {
        if c.utf32 != 64 {
            print(c)
            continue
        }
        print("$\"")
        for d in s {
            if d == '"' {
                print("\\\"")
            } else if d == '\\' {
                print("\\\\")
            } else if d == '\n' {
                print("\\n")
            } else {
                print(d)
            }
        }
        print("\"")
    }
    return 0
}
