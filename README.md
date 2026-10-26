# Goose Guide

This repository collects the Goose syntax I worked through while learning the language in preparation for contributing to the
[Goose project](https://github.com/aardappel/goose). It is a learning space: notes, reference material and small programs written to understand how the language works, from basic program structure through to its memory model, type system and tooling.

It is not part of the official Goose distribution. For the authoritative specification, tutorial and reference, see the `docs/` directory of the upstream repository.

---

## About Goose

Goose is a memory-safe systems programming language designed by Wouter van
Oortmerssen. Its main characteristics are:

- No heap allocator, garbage collector, reference counting or destructors.
  Dynamic data lives on compiler-managed data stacks and is released when its
  owning scope ends.
- No lifetime annotations and no `unsafe`. The compiler infers the root of
  every reference and rejects references that could outlive their data.
- Familiar C- and Rust-like syntax: `fn`, `let`/`var`, `struct`, `enum`,
  `match`, `for x in xs`.
- Whole-program compilation to C, with a bundled TinyCC backend that can
  compile and run programs in-process.

---

## Repository Contents

```
goose-guide/
├── README.md         This file
├── hello.goose       A minimal first program
├── 01-…30-*.goose    One runnable, commented example per syntax.md topic
├── 24-modules/       Supporting package + data file for topic 24
├── 27-calling-c/     C sources and a C host program for topic 27
├── 27-calling-c.build  Build sidecar that tells Goose to compile impl.c
└── docs/
    ├── goose.md      Orientation to the Goose repository: design, layout,
    │                 completed features, open work and contribution areas
    ├── syntax.md     Condensed cheat sheet covering the full language syntax
    └── setup.md      Building, testing and keeping a local Goose checkout
                      up to date on macOS
```

### docs/syntax.md

The core of this repository. A single-page reference of the Goose syntax with
a short example for each feature, covering:

- Program skeleton, comments, identifiers and literals
- Variables (`let`, `var`, `const`) and the type system
- Scalars, operators, casts and conversions
- Arrays, strings, slices, structs and enums with `match`
- References, optionals and relative references
- Control flow, loops and functions
- Generics, function values and blocks
- Recursion and error handling (`return ... from`, `assert`, `abort`)
- Pools, index types and compile-time `const for`
- Modules, packages, namespaces and globals
- Threads, serialization and C interoperability
- Function qualifiers, builtins, operator precedence and the standard library
- Features the language intentionally does not provide

### docs/goose.md

A guide to the upstream Goose repository: what the language is, how the
compiler and runtime are organized, which features are complete, what remains
open, and where contributions are most useful.

### docs/setup.md

Step-by-step instructions for cloning, building, testing and updating Goose
from source, along with the contribution workflow used against the upstream
project.

---

## Getting Started

Build the Goose compiler by following [docs/setup.md](docs/setup.md). Once the
`goose` binary is available, run the example program:

```bash
goose hello.goose
```

Other useful commands:

```bash
goose check hello.goose     # typecheck only
goose build hello.goose     # produce a native executable
goose format hello.goose    # format the source file in place
```

The example program:

```goose
import std;

fn main() {
    print("Hello, How are you ?");
}
```

---

## Topic Examples

Each numbered file covers one section of [docs/syntax.md](docs/syntax.md)
(sections 1–30). Every line is commented with what the syntax does and why,
and `print` calls show the result when you run it. Lines that would fail to
compile are kept as commented-out code with the compiler's error message.

| # | File | # | File |
|---|---|---|---|
| 01 | `01-program-skeleton.goose` | 16 | `16-loops.goose` |
| 02 | `02-comments-identifiers-keywords.goose` | 17 | `17-functions.goose` |
| 03 | `03-literals.goose` | 18 | `18-generics-function-values-blocks.goose` |
| 04 | `04-variables-let-var-const.goose` | 19 | `19-recursion.goose` |
| 05 | `05-types-at-a-glance.goose` | 20 | `20-errors-return-from-assert-abort.goose` |
| 06 | `06-scalars-arithmetic-operators.goose` | 21 | `21-pools-reusable.goose` |
| 07 | `07-casts-and-conversions.goose` | 22 | `22-index-types-checkfree.goose` |
| 08 | `08-arrays.goose` | 23 | `23-const-for.goose` |
| 09 | `09-strings-and-printing.goose` | 24 | `24-modules-packages-namespaces-globals.goose` |
| 10 | `10-slices.goose` | 25 | `25-threads.goose` |
| 11 | `11-structs.goose` | 26 | `26-serialization.goose` |
| 12 | `12-enums-and-match.goose` | 27 | `27-calling-c.goose` |
| 13 | `13-references-and-optionals.goose` | 28 | `28-function-qualifiers.goose` |
| 14 | `14-relative-references.goose` | 29 | `29-builtins-and-array-members.goose` |
| 15 | `15-control-flow.goose` | 30 | `30-operator-precedence.goose` |

### Running them

Run every command from the `goose-guide/` directory. Files 24 and 27 find
their supporting files through paths relative to this directory.

Almost every file runs the usual way:

```bash
goose 08-arrays.goose
```

Three topics need a closer look.

#### 24 — Modules and packages

```bash
goose 24-modules-packages-namespaces-globals.goose
goose 24-modules-packages-namespaces-globals.goose -- hello world   # with program arguments
```

Everything after `--` is passed to the program, not to the compiler. The file
reads the arguments with `os::arg(i)` and prints them.

What happens when you run it:

- `import geolib from "./24-modules/geolib";` declares a **local package**
  named `geolib`. Goose loads its entry module `24-modules/geolib/geolib.goose`
  directly from that folder. Nothing is copied or installed, so edits to the
  library show up on the next run.
- `geolib.goose` puts its declarations in `namespace geolib`. The main file
  therefore calls them as `geolib::norm1(p)`. A plain `norm1(p)` is an
  "unknown function" error.
- Inside the package, `import .helpers;` loads `helpers.goose` relative to the
  importing file. `import util.strings;` loads `util/strings.goose` relative
  to the package root.
- `embed_file("24-modules/table.bin")` copies that file's bytes into the
  program at compile time. The program prints them as `ABC`.
- The file also shows globals and their initialization order before `main`.

```
24-modules/
├── table.bin                 3 bytes ("ABC") read by embed_file
└── geolib/
    ├── geolib.goose          package entry module (namespace geolib)
    ├── extra.goose           second module, imported as `import geolib.extra;`
    ├── helpers.goose         imported with `import .helpers;`
    └── util/strings.goose    imported with `import util.strings;`
```

#### 27 — Calling C, and being called from C

This topic has two halves.

**Goose calling C.** This needs a C compiler (`cc` or `clang`) installed. Run
it the normal way:

```bash
goose 27-calling-c.goose
```

What happens when you run it:

1. Goose sees the **sidecar file** `27-calling-c.build`. It has the same base
   name as the `.goose` file and sits next to it. It contains
   `c_sources = ["27-calling-c/impl.c"];`, so Goose compiles `impl.c` and
   links it into the program.
2. `extern fn name(...) -> T;` declarations bind Goose signatures to C
   functions. Some come from libm (`hypot`, `cbrt`) and some from our own
   `impl.c` (`crc32_bytes`, `fill`, `stats_of`, …). A call is a plain C call.
3. An `extern "z" { ... }` block loads the shared zlib library by name at
   startup (`dlopen`). It looks up `zlibVersion` and `crc32` without any C
   code to compile.
4. Slices cross to C as `{ pointer, length }`. Structs cross by pointer
   (`Stats&`). A growable `u8[>..]&` lets C append bytes to a Goose array.

**C calling Goose.** This direction can't be shown with a plain `goose` run,
because C has to be the host program. There are two steps:

```bash
# 1. Have Goose generate C code plus a header for exports.goose
goose --standalone --header /tmp/exports.h -o /tmp/exports.c 27-calling-c/exports.goose

# 2. Compile the C host together with that generated code, then run it
cc -I/tmp -o /tmp/host 27-calling-c/host.c /tmp/exports.c -lm && /tmp/host
```

Expected output:

```
[goose] main ran inside goose_init
[c] hello() -> "Hello from Goose!" (17 bytes)
[c] c_add(20, 22) = 42
[c] c_add(1, 2)   = 3
[c] call_count()  = 2
```

What happens:

- `export fn hello()` and `export "c_add" fn add(...)` in `exports.goose`
  become ordinary C functions. `--header` writes their declarations to
  `exports.h`.
- `--standalone` produces a C file with no `main()` of its own. `host.c`
  supplies `main`.
- `host.c` must call `goose_init(argc, argv)` once before anything else. That
  sets up the Goose runtime and globals and runs the Goose `main`, which is
  why the `[goose]` line prints first.
- Goose globals persist between calls, so `call_count()` returns 2.
- A `const u8[:]` return value reaches C as a pointer plus a length
  out-parameter. It is **not** NUL-terminated, so `host.c` prints it with
  `%.*s`.

```
27-calling-c.build        sidecar: tells Goose to compile 27-calling-c/impl.c
27-calling-c/
├── impl.c                C functions that 27-calling-c.goose calls
├── exports.goose         Goose functions exported to C
└── host.c                C program (with main) that calls into exports.goose
```

#### 25 — Threads

The in-process runner (`goose file.goose`) doesn't support threads yet, so
build a native executable and run that instead:

```bash
goose build 25-threads.goose -o /tmp/25-threads && /tmp/25-threads
```

---

## Purpose

The goals of this repository are to:

1. Build a working understanding of the full Goose syntax and semantics.
2. Keep a concise, searchable reference for day-to-day use.
3. Document the setup and workflow required to contribute to the upstream
   project.

---

## References

- Upstream repository: https://github.com/aardappel/goose
- Community discussion: https://discord.gg/397eZdbnsR

Goose is licensed under the Apache License 2.0. The notes in this repository
are derived from the upstream documentation for personal learning purposes.
