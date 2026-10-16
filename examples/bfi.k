// A brainfuck interpreter: the program from the file named on the command
// line, or two built in. The tape is 65536 cells that wrap, as the pointer
// does. A `!` ends the program and starts its input, as swift-bf has it,
// so a source carries its own data; without one, `,` reads stdin. With no
// input left, `,` halts. Unmatched brackets are reported with their offset.
#import <stdio.h> as C

struct program {
    code: Bytes          // the commands, comments stripped
    jump: $[int64]         // for each [ and ], the index of its match
    input: Bytes         // the text after the first !
    embedded: bool       // whether there was one: then , reads input, else stdin
}

extend program {
    // the commands of src and their matching brackets, or why there are none
    static let parse(src:Bytes^):Result<Self, String> {   // a function of the type (#111)
        var p:Self = {Bytes(), $[], Bytes(), false}
        var offsets:$[int64] = $[]       // where each command came from, for messages
        var stack:$[int64] = $[]
        let n = src^.count as int64
        var i:int64 = 0
        while i < n {
            let c = src^[i]
            if c == '!' {
                p.input = src^[i + 1...]
                p.embedded = true
                break
            }
            if c == '>' || c == '<' || c == '+' || c == '-' || c == '.' || c == ',' || c == '[' || c == ']' {
                p.code += c
                offsets += i
            }
            i += 1
        }
        p.jump = Array<int64>(p.code.count)
        for k in 0..<p.code.count as int64 {
            let c = p.code[k]
            if c == '[' {
                stack += k
            } else if c == ']' {
                if stack.count == 0 { return err($`unmatched ] at offset ${offsets[k]}`) }
                let open = stack.pop()
                p.jump[open] = k
                p.jump[k] = open
            }
        }
        if stack.count > 0 { return err($`unmatched [ at offset ${offsets[stack[0]]}`) }
        return p
    }

    let run():() {                                        // a method: .code is self.code (#139)
        var tape = Bytes(65536)
        var sp:int64 = 0
        var ip:int64 = 0
        var at:int64 = 0                 // the next byte of the embedded input
        let n = .code.count as int64
        while ip < n {
            switch .code[ip] {
            case '>': sp = (sp + 1) % 65536
            case '<': sp = (sp + 65535) % 65536
            case '+': tape[sp] += 1
            case '-': tape[sp] -= 1
            case '.': putchar(tape[sp])
            case ',':
                if .embedded {
                    if at >= .input.count as int64 { return }
                    tape[sp] = .input[at]
                    at += 1
                } else {
                    let c:int32 = getchar()
                    if c < 0 { return }
                    tape[sp] = c as uint8
                }
            case '[': if tape[sp] == 0 { ip = .jump[ip] }
            case ']': if tape[sp] != 0 { ip = .jump[ip] }
            default:
            }
            ip += 1
        }
    }
}

// parses and runs src; 1 and a message on stderr if it does not parse
let interpret(src:Bytes^):int32 {
    var parsed = program.parse(src)
    if let err(why) = parsed {
        fprintf(stderr, "%s\n", why.cstr)
        return 1
    }
    parsed.ok.run()
    fflush(stdout)
    return 0
}

let hello := "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."
let echo := "+[,<>.]-!Hello, Kelvin!\n"   // the eight commands, and their input after the !

let main(argc:int32, argv:[cstr]):int32 {
    if argc > 1 {
        let f:FILE^ := fopen(argv[1], "r")
        if f.isNull {
            perror(argv[1])
            return 1
        }
        var src = Bytes()
        var c:int32 = fgetc(f)
        while c >= 0 {
            src += c as uint8
            c = fgetc(f)
        }
        fclose(f)
        return interpret(&src)
    }
    var h = Bytes(hello)
    var e = Bytes(echo)
    if interpret(&h) != 0 { return 1 }
    return interpret(&e)
}
// out: Hello World!
// out: Hello, Kelvin!
