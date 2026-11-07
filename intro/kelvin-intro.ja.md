<!-- layout: title -->
# Kelvin

C を、少しずつ変えていく。

C の静かな代替。ABI は 100% 互換のまま。

<!-- notes: Kelvin は、C を知っていて C が好きな人のための言語です。C 連携機能を備えた新言語ではありません。C そのものに、変更を一つずつ加えたものです。 -->

---

<!-- layout: flow -->
# Kelvin は綴りの違う C

`kelvinc` は Kelvin を C に翻訳し、あなたの C コンパイラに渡す。

- **hello.k**: あなたが書くもの
- **kelvinc**: Kelvin が足した分を検査する
- **C ソース**: 読める C。`#line` で `.k` に戻れる
- **cc**: いつもの clang か gcc
- **hello**: ふつうのネイティブプログラム

型もレイアウトも呼び出し規約も意味論も、作りからして C のもの。

<!-- notes: VM も新しいバックエンドも、頼んでいないランタイムもありません。kelvinc が検査するのは、所有者、Optional、Result など Kelvin が足した分だけです。残りは C コンパイラに任せ、その診断は .k ファイルを指します。 -->

---

<!-- layout: scale -->
# 名前が設計そのもの

> **Dan**: kelvin の実装を始めよう。`better C` を実装する試みだ。名前は事実上あなたがつけた:
> **Claude**: 私なら **Kelvin** と呼びます。
> C は摂氏 (Celsius) の記号でもあり、Kelvin はその自然な後継です。目盛りの幅は同じなので、C について知っていることはすべて一対一で持ち越せます…
> Kelvin に決めたのは、この駄洒落がそのまま設計仕様でもあるからです。

Dialogue.md 第1節・第2節の和訳。次点は Sequel、P、Coda、Seam。

<!-- notes: 名前を見つけたのは Claude です。プロジェクトが始まる前の会話でのことで、Dan がその答えを貼りつけて開発が始まりました。摂氏の 1 度は 1 ケルビンですから、目盛りを覚え直す必要はありません。省略した部分では未定義動作をなくすと約束していましたが、それは初日で消えました。この先のスライドのとおり、Kelvin は未定義動作を含めて C の意味論を保ちます。駄洒落のほうは設計として残りました。 -->

---

<!-- layout: compare -->
# 宣言は左から右へ読む

```c title="C"
#include <stdint.h>

struct point { int64_t x, y; };

int64_t add(int64_t a, int64_t b) {
    return a + b;
}

int main(void) {
    const int64_t k = 7;
    int32_t n = 0;
    int32_t *p = &n;
    *p = 9;
    return n;
}
```

```kelvin title="Kelvin"
struct point { x: i64; y: i64 }

let add(a:i64, b:i64):i64 {
    return a + b
}

let main():i32 {
    let k = 7
    var n:i32 = 0
    var p:i32^ := &n
    p^ = 9
    return n
}
```

<!-- notes: 型は名前の後ろに書きます。ポインタは後置の ^ で、p^ は C の *p、p^.m は C の p->m です。let は変わらず、var は変わります。型はサイズを明示します。struct は名前だけで呼べます。セミコロンは省略できます。 -->

---

<!-- layout: code -->
# C は C のまま

```kelvin title="fromc.k"
#import <stdio.h> as C    // C のヘッダそのもの

let square(n:i32):i32 { return n * n }

let main():i32 {
    let k = 7             // i64 の let
    var total:i32 = 0
    var p:i32^ := &total  // C の int32_t *
    p^ = square(3)
    printf("%d %lld\n", total, k)
    return 0
}
```

```text title="出力"
9 7
```

- **ヘッダ**はそのまま読み込む
- **優先順位と型変換**は C のもの
- **未定義動作**も、書いたとおりに残る

<!-- notes: C のヘッダを import して、そのまま呼べます。バインディングは要りません。優先順位も型変換も C のままで、未定義動作をトラップで隠すこともしません。自分の C が何をするか分かっていれば、これが何をするかも分かります。 -->

---

<!-- layout: compare -->
# 書き出される C が読める

```kelvin title="sum.k"
struct point { x: i64; y: i64 }

let sum(p:point):i64 {
    return p.x + p.y
}

let main():i32 {
    var total:i64 = 0
    for i in 0..<3 { total += i }
    return i32(total)
}
```

```c title="kelvinc --emit-c sum.k" emit
struct point
{
    int64_t x;
    int64_t y;
};
int64_t sum(const struct point p)
{
    return p.x + p.y;
}
```

`let` の引数はただの `const`。Kelvin の struct は C の struct で、Kelvin の関数は C の関数。

<!-- notes: kelvinc --emit-c は生成した C を表示します。自分でも書けそうな C です。let の引数はただの const です。「ABI は 100% 互換」とはこういう意味です。Kelvin の struct は C の struct で、Kelvin の関数は C の関数です。 -->

---

<!-- layout: why -->
# なぜ C なのか、2026 年に

C は自分の足を撃てる言語で、米国政府も避けよと言っている。

反対意見。どれも正しい

それでも Kelvin は C の上に立つ

- **2024**: ホワイトハウスがメモリ安全な言語を求め、C と C++ を名指しした
- **2025**: NSA と CISA も同じことを説く
- **いま**: Go、Rust、Swift はメモリ安全で、ネイティブバイナリも出せる
- **1**: **libc** (macOS なら libSystem) はなくならない
- **2**: **C コンパイラ**は最も基本のコンパイラ基盤で、思いつくどのプラットフォームにもある
- **3**: **C の上に立つ**ので、大きさは 10 分の 1 以下
- **4**: **メモリ安全性**は C の機能の範囲で実現でき、見た目は Rust や Swift に近づけられる

<!-- notes: この反論は正しいので、真剣に受け止めましょう。ホワイトハウスの報告書は 2024 年 2 月の Back to the Building Blocks、NSA と CISA の手引きは 2025 年 6 月の Memory Safe Languages です。2023 年の The Case for Memory Safe Roadmaps は、例として Go、Rust、Swift を挙げています。Kelvin の答えは「C は安全だ」ではありません。C はあらゆるものがすでに立っている地面なので、安全性を足すならその上が一番安くつく、という答えです。続く 3 枚で順に見ていきます。 -->

---

<!-- layout: code -->
# libc と cc はもうそこにある

```text title="Mac でビルドした hello world の otool -L"
Kelvin  /usr/lib/libSystem.B.dylib

Rust    /usr/lib/libSystem.B.dylib

Go      /usr/lib/libSystem.B.dylib
        /usr/lib/libresolv.9.dylib

Swift   /usr/lib/libSystem.B.dylib
        /usr/lib/swift/libswiftCore.dylib
```

Go 1.12 のリリースノート: "libSystem is now used when making syscalls on Darwin." (Darwin のシステムコールは libSystem 経由になった)

- **libc は残る**: ここでは 4 つとも、メモリ安全な 3 つも含めてリンクしている
- **cc はどこにでもある**: 最も基本のコンパイラ基盤で、思いつくどのプラットフォームにもある
- **だから Kelvin は両方を再利用**し、移植の必要がない

<!-- notes: メモリ安全な言語も libc からは離れられません。Go はかつて macOS でカーネルを直接呼んでいましたが、Go 1.12 からは libSystem を経由しています。Linux はシステムコールのインターフェイスが安定しているので、Go や Rust の musl ターゲットは libc を使わずに済みます。それでも他の多くの OS では、OS 自身のインターフェイスは C です。新しいプラットフォームにはまず C コンパイラがあるので、Kelvin はそのためのバックエンドを書かずに済みます。 -->

---

<!-- layout: sizes -->
# C の上に立つから Kelvin は小さい

10 分の 1 以下の大きさで、しかもその半分以上は Unicode データ。

Kelvin の 13.7 MB の内訳

2026-11-07 に `intro/measure.sh` で各既定ブランチを計測。LLVM と C コンパイラはどれにも数えていない。他の 3 つはずっと多くのことをこなしている。

| プロジェクト | 追跡している全ファイル (MB) | コンパイラ自身のソース (MB) |
|---|---|---|
| Kelvin | 13.7 | 1.2 |
| Go | 155.6 | 24.9 |
| Swift | 217.2 | 58.9 |
| Rust | 230.1 | 35.0 |

- **Unicode データ**: 8.6
- **kelvinc**: 1.2
- **その他**: 3.9

<!-- notes: 追跡している全ファイルとは、テストや文書も含めたリポジトリの全部で、Kelvin の 11 倍から 17 倍です。8.6 MB の Unicode Character Database を除くと Kelvin は 5.1 MB で、30 倍から 45 倍になります。コンパイラだけなら 21 倍から 49 倍です。理由については公平に話しましょう。これらのプロジェクトには、はるかに大きなライブラリ、自前のバックエンドや LLVM との深い統合、Windows 対応、そして長い年月があります。そして Kelvin が頼る C コンパイラ自身も数百万行あります。そこが肝心で、それはもうあなたのマシンにあるので、Kelvin が抱える必要がないのです。 -->

---

<!-- layout: compare -->
# 見た目は Rust や Swift、変換先は C

```kelvin title="safer.k"
let half(n:i64):i64? {
    if n % 2 != 0 { return none }
    return n / 2
}

let main():i32 {
    let s = $"owned"
    let h = half(7)
    println(s, " ", h)
    return 0
}
```

```c title="kelvinc --emit-c safer.k" emit
struct _kv_opt_i64 half(const int64_t n)
{
    if (n % 2 != 0)
    {
        return _kv__kv_opt_i64_make_none();
    }
    return _kv__kv_opt_i64_make_some(n / 2);
}

__attribute__((cleanup(kv_string_free)))
kv_string s = KV_STRING_LIT("owned");
const struct _kv_opt_i64 h = half(7);
```

所有者は自動で解放され、`T?` は取り出さないと使えず、`xs[i]` は検査される。すべて素の C で。`^` ポインタと C の未定義動作は残るので、Kelvin は「より安全な C」であり、Rust の保証はない。

<!-- notes: Optional はタグつきの C の struct です。所有者は C の cleanup 属性とふつうの関数呼び出しです。添字は検査をするふつうの関数です。C コンパイラから見て新しいものは何もありません。限界ははっきり言っておきましょう。Kelvin は Rust のようにメモリ安全性を証明しません。生のポインタは C と同じようにぶら下がり得ますし、印もつきません。ここで示しているのは、これらの機能に C に欠けているものは要らない、ということです。 -->

---

<!-- layout: dollar -->
# $ ひとつで、二つの世界が共存する

C 本来のリテラルはそのまま。`$` を一文字つければ、柔軟な版が隣に並ぶ。

| C 本来: 硬直、メモリ安全でない | | $ つき: 柔軟、メモリ安全 | |
|---|---|---|---|
| "text" | `cstr`: 固定バイト列への生ポインタ | $"text" | `String`: バイト列を所有し、伸びる |
| [1, 2, 3] | 固定配列: `a[7]` を誰も検査しない | $[1, 2, 3] | `Array`: 伸びる。`xs[7]` はプログラムを止める |
| {1, 2} | struct のフィールドを順に | ${"ann": 31} | `Dictionary`。`${1, 2}` は `Set` |
| // text | コメント: C にこのリテラルはない | $/k.l/i | `RegExp`: パターンはコンパイル時に検査 |

`:=` で中へのポインタを取らないかぎり、`$` の側は C のようには誤用できない。

> 「人間としては、短縮形がほしくなる」

Dan、$ が生まれた日に

```kelvin title="check: the slide's table compiles, and prints this"
#import <RegExp>
struct pair { a: i64; b: i64 }
let main():i32 {
    let t := "text"
    var a:[i32](3) = [1, 2, 3]
    let f:pair = {1, 2}
    var s = $"text"
    s += "!"
    var xs = $[1, 2, 3]
    xs += 4
    let d = ${"ann": 31}
    let u = ${1, 2}
    let re = $/k.l/i
    println(t, " ", a[1], " ", f, " ", s, " ", xs, " ", d, " ", u.count, " ", re.test($"Kelvin"))
    return 0
}
```

```text
text 2 {a: 1, b: 2} text! [1, 2, 3, 4] {"ann": 31} 2 true
```

<!-- notes: これは Dan が Kelvin で一番の発明だと考えているものです。問題はこうでした。C 本来の配列や文字列を残さなければ C ではなくなる。かといって String("...") は長すぎて、誰も書きたがらない。それを一文字で解決しました。C の書き方は何も変えていないので、C のコードも C の習慣もそのまま通用し、リテラルごとにどちらの世界かを選べます。これは型にも及びます。$[i64] は i64 の Array、${String: i64} は Dictionary です。$/.../ には #import <RegExp> が必要です。// はもともとコメントでした。引用は Dialogue.md 第93節の Dan の言葉の和訳で、$ が生まれた日のものです。 -->

---

<!-- layout: pointers -->
# ポインタは少し面倒にした。わざと

```c title="C: かつて称賛された定石"
#include <stdio.h>

int main(void) {
    char a[4] = "abc", b[4];
    char *p = b;
    const char *q = a;
    while ((*p++ = *q++) != '\0')
        ;
    puts(b);
    return 0;
}
```

```kelvin title="Kelvin: 一行に一手"
let main():i32 {
    var a:[u8](4) = "abc"
    var b:[u8](4)
    var p:u8^ := &b[0]      // ポインタは :=
    var q:u8^ := &a[0]
    while q^ != 0 {
        p^ = q^
        p++                 // これは文
        q++
    }
    p^ = 0
    println(&b[0] as cstr)
    return 0
}
```

```text
abc
```

```kelvin-error given="var n:i32 = 0; var m:i32 = 1; var p:i32^ := &n; var q:i32^ := &m"
while (p++^ = q++^) != 0 { }
```

```text
'++' is a statement in Kelvin, not a value: step the pointer on a line of its own
```

```kelvin-error given="var n:i32 = 0; var m:i32 = 1; var p:i32^ := &n; var q:i32^ := &m"
p = q
```

```text
'p' is a reference (i32^): assign it with ':=', not '='
```

<!-- notes: (*p++ = *q++) != '\0' はもうカッコよくありません。ポインタはなくなっていませんし、C の算術も未定義動作もそのままで、取り上げたものはありません。書くのが少し面倒になっただけで、それが狙いです。:= を使うのでポインタの代入はどれも目立ち、ぶら下がりを探すときに真っ先に見る場所になります。代入も ++ も文なので、一行で三つのことはできません。++ はポインタ専用で、数値に使うと += 1 と書くようエラーが教えてくれます。そもそも文字列なら、このループは書きません。String なら s.copy() です。 -->

---

<!-- layout: code -->
# 所有者は自分で解放される

```kelvin title="owners.k"
let shout(name:cstr):String {
    var s = String(name)   // バイト列を所有
    s += "!"
    return s               // 呼び出し元へムーブ
}

let main():i32 {
    let hi = shout("hello")
    var xs = $[3, 1, 2]    // Array<i64>
    xs += 4
    println(hi, " ", xs, " ", xs.count)
    return 0
}                          // hi と xs はここで解放
```

```text title="出力"
hello! [3, 1, 2, 4] 4
```

- **ブロック**は変数が所有するものを解放する
- **`return` と引数渡し**は所有者をムーブする
- **`=` はコピーしない**: `.copy()` と書くか、`&` で借りる

<!-- notes: String、Bytes、Array、Dictionary、Set、Bits はヒープに置かれます。ガベージコレクタも隠れたコピーもありません。C の cleanup 属性とふつうの関数呼び出しにコンパイルされます。 -->

---

<!-- layout: errors -->
# 間違いは Kelvin の言葉で告げられる

```kelvin-error
int x = 3
```

```text
'int' is not a Kelvin type; use i32 or u32
```

```kelvin-error
let n = 0
n += 1
```

```text
'n' is a let and cannot change; declare it with var
```

```kelvin-error
let a = $"x"
take(a)
println(a)
```

```text
'a' was moved out and holds nothing now: assign it anew before using it
```

```kelvin-error
let m:i32? = 3
println(m + 1)
```

```text
i32? has no operator '+': compare with == and !=
```

<!-- notes: kelvinc は Kelvin が足した分を検査し、何が悪いのかを、たいていは直し方とともに伝えます。メッセージは英語です。C の習慣も知っていて、int、*p、p->m、10UL と書くとヒントを出します。C 本来の部分は C コンパイラが検査します。 -->

---

<!-- layout: code -->
# 失敗は値である

```kelvin title="result.k"
#import <stdio.h> as C
#import <errno.h> as C

let open(path:cstr):Result<FILE^, i32> {
    let f:FILE^ := fopen(path, "r")
    if f.isNull { return err(errno) }
    return f                        // T は ok(T) になる
}

let check(path:cstr):Result<i64, i32> {
    let f := try open(path)         // err は上へ
    fclose(f)
    return 1
}

let main():i32 {
    println(check("/no/such/file"))
    let first:i64? = none
    println(first ?? 42)
    return 0
}
```

```text title="出力"
err(2)
42
```

- **`T?` と `Result<T, E>`** の中身は C の struct
- **`try`** はエラーを上へ渡す
- **`??`** は代わりの値を与える

<!-- notes: C は値をポインタ経由で返し、エラーコードをその脇に置きます。ここでは関数が両方を一つの値として返します。C の fopen と errno を直接包んでいます。2 は ENOENT です。 -->

---

<!-- layout: code -->
# どの型にもメソッドと演算子を足せる

```kelvin title="money.k"
struct money { cents: i64 }

extend money {
    static let +(a:Self, b:Self):Self { (Self){a.cents + b.cents} }
    static let <(a:Self, b:Self):bool { a.cents < b.cents }
    let dollars:f64 { .cents / 100.0 }
    let doubled():Self { self + self }
}

let main():i32 {
    let a:money = {150}
    let b:money = {275}
    var bills = $[b, a]
    bills.sort()              // 自前の < で
    println(bills)
    println((a + b).cents, " ", a.doubled().dollars)
    return 0
}
```

```text title="出力"
[{cents: 150}, {cents: 275}]
425 3.0
```

- **メソッドと属性**は `extend T { }` に
- **演算子**は型で選ばれる関数
- **C から見れば**ただの関数

<!-- notes: これは C++ ではありません。クラスも継承も vtable もありません。メソッドは、型の名前を含む名前を持つ C の関数です。struct のレイアウトはまったく変わりません。 -->

---

<!-- layout: code -->
# コレクションとテキストは組み込み

```kelvin title="values.k"
struct point { x: i64; y: i64 }

let main():i32 {
    let squares = (1...5).map { $0 * $0 }
    let even = squares.filter { $0 % 2 == 0 }
    let ages = ${"ann": 31, "bob": 42}
    let name = $"ann"
    println(squares, " ", even)
    println(squares.sorted { $0 > $1 })
    println(ages)
    println((point){3, 4})
    println(`${name} is ${ages["ann"]!}`)
    return 0
}
```

```text title="出力"
[1, 4, 9, 16, 25] [4, 16]
[25, 16, 9, 4, 1]
{"ann": 31, "bob": 42}
{x: 3, y: 4}
ann is 31
```

- **`$[...]` と `${...}`** で Array、Dictionary、Set を作る
- **`{ $0 * $0 }`** は無名関数で、クロージャではない
- **`println`** はどんな値でも表示する

<!-- notes: どれもプレリュードにあるので import は要りません。C にクロージャはないので、無名関数は外側の関数の変数を使えず、kelvinc がそう告げます。print と println は struct を含むどんな値にも使え、書式文字列は要りません。 -->

---

<!-- layout: code -->
# async と await の実体はスレッド

```kelvin title="tasks.k"
let count(lo:i64, hi:i64):i64 {
    var n:i64 = 0
    for i in lo..<hi { n += i % 3 == 0 ? 1 : 0 }
    return n
}
let label(n:i64):String { $`${n} of them` }

let main():i32 {
    var parts:$[Task<i64>] = $[]
    for q in 0..<4 {
        parts += async count(q * 1000, (q + 1) * 1000)
    }
    var total:i64 = 0
    for i in 0..<parts.count { total += await parts[i] }
    let text = await async label(total)
    println(text)
    return 0
}
```

```text title="出力"
1334 of them
```

- **`async f(x)`** は `f` を専用のスレッドで走らせる
- **`await`** は待って、その値を返す
- **所有者**は呼び出し元へムーブで戻る

<!-- notes: イベントループも色つきのスケジューラもありません。async f(x) はスレッドを起こして、すぐに Task を返します。await はそれを join します。pthreads で書くものと同じで、間違える余地が少ないだけです。 -->

---

<!-- layout: compare -->
# C からも Kelvin を呼べる

```kelvin title="geo.k" lib=geo
struct point { x: f64; y: f64 }

let dist2(a:point, b:point):f64 {
    let dx:f64 = a.x - b.x
    let dy:f64 = a.y - b.y
    return dx * dx + dy * dy
}

// kelvinc --lib geo.k で
// geo.kh、libkgeo.a と
// libkgeo.dylib か libkgeo.so ができる
```

```c title="main.c" link=geo
#include <stdio.h>
struct point { double x, y; };
double dist2__point__point(struct point a,
                           struct point b);

int main(void) {
    struct point a = {0, 0}, b = {3, 4};
    printf("%.1f\n",
           dist2__point__point(a, b));
    return 0;
}
```

```text title="出力"
25.0
```

Kelvin からは `#import <geo>`。C からはふつうのライブラリ。

<!-- notes: kelvinc が作るライブラリは C なので、C のプログラムから直接リンクできます。モジュールの関数は、オーバーロードが共存できるように引数の型を含む名前になり、--emit-c で確かめられます。共有ライブラリには libkelvin がライブラリパス上に必要です。Kelvin からは #import <geo> だけです。 -->

---

<!-- layout: cards -->
# ライブラリは一つずつ import する

- **IO**: ファイル、パイプ、プロセス
- **OS and SYS**: ディレクトリ、環境変数、プロセス
- **JSON**: `JSON.parse` と `JSON.stringify` を JS のとおりに
- **SION**: SION の値。JSON の拡張
- **MsgPack**: SION の MessagePack
- **RegExp**: `$/pattern/flags`。JS の正規表現
- **UnicodeData**: 正規化、書記素、大文字小文字の変換
- **math**: float と複素数のための `math.h`
- **自作**: `kelvinc --lib M.k` で作れる

どれも `#import <M>` で読み込む。import しないものは入らない。

<!-- notes: 核は C で、プレリュードが String や Array などを担い、それ以外はすべて明示的な import です。documents/ の各文書 (英語) には、この三つのどれについての説明かが書いてあります。 -->

---

<!-- layout: stats -->
# 合意した変更を一つずつ

- **472** 回の番号つき変更
- **1,205** 個のテスト。clang と gcc 15 で
- **9** 個の CI ジョブ。macOS、Ubuntu、FreeBSD

> 「ちょっと、先走りすぎだよ!」

初日のコンパイラは、トラップもスライスも `defer` も一度に足した。それを捨てて素の C に戻り、以来 C から離れるたびに一つずつ提案し、合意してきた。

- **Design.md** は何を決めたかを記録する
- **Dialogue.md** はその経緯を、交わした言葉のまま記録する

<!-- notes: Kelvin は Dan Kogai が設計し、Claude とともに書きました。引用は初日のもので、Dialogue.md 第5節の和訳です。このリセット以来、どの変更にも番号があり、Design.md に行が、Dialogue.md に節があるので、どの機能についてもなぜあるのかを読めます (どちらも英語です)。テストプログラムは ASan の下でも走り、kelvinc と kc は ASan と UBSan の下でも走ります。 -->

---

<!-- layout: selfhost -->
# Kelvin は自分のコンパイルを学習中

`kc` は Kelvin で書かれたコンパイラ。自分自身を不動点までビルドする。push のたびに CI で。

- **いま**: テストプログラムと例の 354 本中 176 本
- **次に**: `kelvinc` と同じ能力へ
- **その先**: C を飛ばし、`kc` からアセンブリか LLVM IR へ
- **いつか**: バックエンドもすべて Kelvin で

| 変更 | kc がビルドできるプログラム数 (番号つき変更ごと) |
|---|---|
| #466 | 147 |
| #469 | 148 |
| #470 | 153 |
| #471 | 162 |
| #472 | 176 |

<!-- notes: kc は実験段階で、Kelvin で約 22,000 行あります。kelvinc は C で 24,000 行です。ステージ 2 とステージ 3 は同じ C を書き出し、約 30,000 行です。C と同じように libc は使ってよく、自前の C だけは使いません。ビルドした各プログラムは、kelvinc でビルドしたものと同じ出力を出さなければなりません。 -->

---

<!-- layout: try -->
# 試してみる

```sh
git clone https://github.com/dankogai/kelvin
cd kelvin
make
./kelvinc --run examples/hello.k
./kelvinc --emit-c examples/hello.k
make install PREFIX=~/.local
```

- **必要なもの**: C11 コンパイラ、GNU make、Python 3
- **動く環境**: macOS、Linux、FreeBSD。Windows は不可
- **状態**: 0.1.0。今後の 0.x で変わることがある
- **最初に読む**: `documents/versusC.md`
- **VS Code なら**: `make vscode`
- **ライセンス**: MIT

<!-- notes: documents/versusC.md は C との違いを一覧にしたもので、英語です。make test は文書の例をコンパイルするので、例が古びることはありません。最初のリリースは 2026 年 11 月にタグづけされました。 -->

---

<!-- layout: closing -->
# C の知識は、すべて持ち越せる

github.com/dankogai/kelvin

MIT ライセンス

<!-- notes: ありがとうございました。ご質問をどうぞ。 -->
