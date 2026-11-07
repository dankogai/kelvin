# Slides introducing Kelvin

24 slides for programmers who know C, about 30 minutes with the speaker
notes, in two languages. `kelvin-intro.md` and `kelvin-intro.ja.md` are the
sources; the rest is made from them.

## Render

```sh
cd intro
npm install
npm run render      # checks the code, then writes the .pptx, .key and .pdf
```

- `npm run check` compiles every code block with `../kelvinc`, and compares
  the output and errors the slides show. Build `../kelvinc` first.
- `npm run pptx` writes only the `.pptx` files, with no need for Keynote.
- One language alone: `node build.js kelvin-intro.ja.md`, and the same for
  `node check.js`.
- `sh measure.sh` reprints the sizes on slide 9, downloading about 500 MB.
- `npm run render` needs Keynote, on macOS.
  - The first run may ask to let your terminal control Keynote: allow it.
  - If Keynote shows a dialog while importing, dismiss it and run again.

## Edit

- Slides are split by a line of `---`.
- `<!-- layout: name -->` picks the layout, one of `build.js`'s `layouts`.
- `<!-- notes: ... -->` holds the speaker notes.
- A ```` ```text ```` block after a code block is what that code prints.
- A change to one language's slides belongs in the other's too.

## Known limits

- The bars on slides 9 and 22 are shapes: Keynote drops the charts pptxgenjs writes.
- Code is set in Menlo, which PowerPoint on Windows replaces.
- The Japanese deck is set in Hiragino, which PowerPoint on Windows replaces too.
- kelvinc's own messages stay in English in the Japanese deck, as it prints them.
