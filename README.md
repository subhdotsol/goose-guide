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
