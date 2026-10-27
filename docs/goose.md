# Goose: Repository Guide

A one-file orientation to this repository: what Goose is, how the code is
organized, what is finished, what is still open, where you can contribute, and
how to set everything up.

For the language syntax, see [syntax.md](syntax.md).

---

## 1. What is Goose?

Goose is a **memory-safe systems programming language** with:

- **No heap allocator, garbage collector, reference counting or destructors.**
  All dynamic data lives on a handful of compiler-managed **data stacks**
  (bump-pointer regions). Memory is freed when its owning scope ends, and
  freeing a large structure costs a single store.
- **No lifetime annotations and no `unsafe`.** The compiler infers the *root*
  of every reference (the variable that bounds its lifetime) and rejects any
  reference that could outlive what it points at.
- **Syntax that looks like C and Rust**: `fn`, `let`/`var`, `struct`, `enum`,
  `match`, `for x in xs`.
- **Compilation to C.** The whole program becomes one C file. A bundled
  **TinyCC** backend compiles and runs it in-process, with no build step.

The headline claim, measured over 16 benchmarks in `bench/`, is that Goose
runs about 3.3x faster than idiomatic C++, 1.16x faster than hand-optimized
C++ and 1.12x faster than the best safe Rust, while using less memory.

### Key ideas that make Goose different

| Idea | What it means |
|---|---|
| Data stacks | At most one resizable value is live per stack, always on top. Growth is a pointer bump and **nothing ever moves**. |
| Stable references | `items.push(x)` returns a reference that stays valid for as long as the array exists, however many pushes come later. |
| Array family | `T[k]`, `T[]`, `T[varint]`, `T[..k]`, `T[..]`, `T[>..]` (grow-only), `T[>..<]` (grow-shrink), `T[:]` (slice). All are stored inline with no pointer to a separate buffer. |
| Inline nested data | A record with strings and sub-arrays is one contiguous block with no pointers. One sample order takes 29 bytes in Goose vs 160 bytes in C++. |
| Two-mode enums | `Shape` (fixed size, indexable) and `Shape..` (each value only as big as its variant). |
| Relative references | `T&<u32>`: a link stored as a narrow offset. Structures built from them are position independent and can be written to disk as is. |
| Verified serialization | `to_bytes` / `from_bytes`. Loading checks every tag, length and link, so hostile data is rejected. |
| In-place construction | Values are built at their final destination through any depth of calls. |
| `return E from f` | Returns from a function any number of frames up the stack. It is checked statically and needs no unwinder and no `Result` type. |
| Zero-cost generics and blocks | Untyped parameters are generic. Function values are compile-time only, so `xs.filter() { it > 0 }` compiles to a plain loop. |
| Threads without shared memory | Each `thread_fn` is a separate program with its own memory. Workers talk through typed queues (`qput`/`qget`). |
| C interop | `extern fn`, `extern "lib" { ... }` (dlopen) and `export fn`. |

### Limitations (by design)

- You must think about where data lives: who owns it and how long its scope lasts.
- Recursive functions cannot keep growable data alive across a recursive call.
- Arrays of variable-size elements can be iterated but not indexed.
- There are no escaping closures, no function pointers, and no dynamic dispatch beyond enum tags.
- Only whole-program compilation is supported.
- A stale slot in a `reusable` pool reads the slot's new owner's value. That is a logic bug, but never memory corruption.

### Who made it

The language was designed by **Wouter van Oortmerssen** (creator of
Lobster and FlatBuffers). The implementation was written almost entirely with
AI ("Claude Fable"). The license is Apache 2.0, and discussion happens on
[Discord](https://discord.gg/397eZdbnsR).

---

## 2. Repository layout

```
goose/
├── src/            The compiler (C++20, about 30k lines; main.cpp includes all headers)
│   └── runtime/    The C runtime that is linked into or embedded with every program
├── stdlib/         Standard library, written in Goose
├── samples/        31 complete example programs (01_tour … 31_mini_doom) + run_samples.py
├── test/           Test suite: fixtures by category + run_tests.py + Python sub-tests
├── bench/          Benchmarks: Goose vs C++ vs Rust, with results.md and summary.md
├── docs/           Tutorial, reference, spec, stdlib, implementation notes, design notes
│   ├── design/     19 design documents (some implemented, some proposals)
│   └── site/       Pandoc-based docs site builder (published to GitHub Pages)
├── scripts/        toolchain.py, check_doc_examples.py, package_release.py
├── tree-sitter/    Tree-sitter grammar (grammar.js, scanner.c, highlights.scm, corpus)
├── vscode/         VS Code extension (TextMate grammar, LSP client, snippets, .vsix)
├── cmake/          libtcc.cmake, package.cmake, linkclosure.cmake, version.cmake
├── third_party/    tinycc (vendored), subprocess.h, cute_spirv
└── .github/        CI (ci.yml), docs site (pages.yml), release builds (release.yml)
```

### The compiler pipeline (`src/`)

**Parse → Resolve → Typecheck → Optimize → BCE → Codegen (C) → JIT or C compiler**

Each pass is a virtual method on `Node` (`Check`, `Opt`, `BceWalk`, `CgX`, ...).
All of a pass's per-node bodies live together in one file. The AST owns
everything in append-only tables.

| Area | Files | Role |
|---|---|---|
| Infrastructure | `includes.h`, `utils.h`, `small_vector.h`, `flat_map.h`, `json.h`, `process.*`, `progress.*`, `version.cpp` | Helpers, child processes, progress output, version |
| Lexer / parser | `lexer.h`, `parser.h`, `ast.h`, `dump.h`, `clone.h` | Hand-written scanner; recursive-descent parser (mirrors spec Appendix D) with error recovery; AST; AST→source dump; cloning per specialization |
| Resolve | `resolve.h`, `expansion_bind.h` | Resolves type names and aliases; binds `const for` |
| Typecheck | `typecheck.h`, `typecheck_types.h`, `typecheck_exprs.h`, `typecheck_flow.h`, `typecheck_calls.h`, `typecheck_builtins.h`, `typecheck_expansion.h`, `typecheck_nodes.h`, `type_queries.h`, `builtins.h` | Whole-program checking in call-graph order. One specialization per (types, roots, writability). Lifetimes, narrowing, definite assignment, overloads, generics, case-function dispatch, builtins |
| Optimize | `optimize.h`, `optimize_basecase.h`, `optimize_tre.h`, `optimize_loops.h`, `optimize_reassoc.h` | Inlining, constant folding, tail-recursion elimination, loop restating for vectorization |
| BCE | `bce.h` | Bounds-check elimination over a difference-constraint domain |
| Codegen | `codegen.h`, `codegen_types.h`, `codegen_frames.h`, `codegen_values.h`, `codegen_construct.h`, `codegen_stmts.h`, `codegen_calls.h`, `codegen_builtins.h`, `codegen_render.h`, `codegen_emit.h`, `codegen_stacks.h`, `codegen_nodes.h` | Emits one C file: packed layouts, calling convention, in-place construction, data-stack accounting |
| JIT | `jit.h` | Hands the C to libtcc and runs it in memory |
| Graphics / shaders | `gfx.h`, `gfx_blob.h`, `shaderc.*` | `embed_shader`: GLSL → SPIR-V blob |
| LSP | `lsp_rpc.h`, `lsp_workspace.h`, `lsp_analysis.h`, `lsp_features.h`, `lsp.h` | `goose lsp`: diagnostics, hover, definition, references, rename, completion, semantic tokens, inlay hints, formatting, ... |
| Packages / build | `packages.h`, `buildfile.h`, `native.h`, `builtin.h`, `toolchain.h`, `build.h`, `blessed.txt` | `import x from "owner/repo@tag"`, `.build` sidecars, toolchain discovery, `goose build` |
| Formatter | `format.h` | `goose format` (keeps the author's line breaks) |
| Runtime | `runtime/runtime.h`, `runtime_impl.h`, `runtime_threads.h`, `runtime_os.h`, `runtime_ext.h`, `goose.h` | C runtime: data stacks, printing, threads and queues, OS layer. `src/runtime_inline.h` is **generated**; do not edit it by hand |

`docs/implementation.md` (7k lines) explains each pass in depth.

---

## 3. Completed features

### Language (all implemented and tested)

- The data-stack memory model with compile-time stack assignment (`--stacks` shows how many stacks a program uses).
- The full array family, slices, `^k` from-end indexing, and strings as `u8` arrays.
- Structs: field defaults, `..` fill, `let`/`const` fields, `pad`, `varint` fields, a resizable tail field, generic structs.
- Enums (ADTs) in fixed and variable mode, `match`, case functions with tag dispatch, recursive enums through relative references.
- Transparent references `T&`, optionals `T?` with narrowing, `.=` rebinding, `.==` identity comparison.
- Relative references `T&<uN>`, `T&<uN in pool>`, and `self` in literals.
- Lifetime inference by roots, liveness-based shrink checks, `const` writability.
- `reusable` pools (`alloc_ref`, `alloc_index`, `free`) and `reusable[]` slice pools.
- Index types (`u32 in a`, `u32 upto a`) and `checkfree fn`.
- `simd fn` multi-versioning (baseline / AVX2 / AVX-512) and `inline fn`.
- `const for` compile-time expansion over fields, variants, types and constants.
- Generics, function values, trailing blocks, nested functions, UFCS.
- Opt-in recursion (`recursive fn`).
- Long-distance returns (`return E from f`), plus `exception::try` / `throw` built on top of them.
- `defer` statements that run when their block ends, and `exception::try`'s `finally` built on them.
- Namespaces (`namespace x;`, `x::name`, `::name`).
- Threads (`thread_fn`, typed queues, contained workers).
- Verified serialization (`to_bytes`, `from_bytes`, `bytes_of`).
- C interop: `extern fn`, `extern "lib" { }` (dynamic, PR #59), `export fn` with `--header`.
- Packages from local directories or git repos, `.build` sidecar files, `embed_file`.

### Tooling

- `goose run | build | check | fetch | format | toolchain | version | lsp | completion | help`
- In-process TinyCC JIT, and native builds with MSVC, clang or gcc.
- A language server, all planned phases done.
- `goose format`.
- A VS Code extension.
- A tree-sitter grammar, with editor configs for Neovim, Helix and Emacs.
- Colored diagnostics, `--diagnostics json`, shell completion, a man page.
- A docs site built with pandoc.
- Prebuilt releases for Windows x64, Linux x64, and macOS (arm64 and Intel).
- A Goose-in-Goose bootstrap compiler, used as a test (`test/goose_in_goose/`).

### Standard library (`stdlib/` plus external packages)

| Module | Purpose |
|---|---|
| `std` | min/max/clamp, bit operations, sort/filter/map/fold/find, heap, dedup, string utilities (find, split, trim, words, join, parse_int, ...), rng, hashing. Lives in the global namespace. |
| `dictionary` | `dictionary<K,V>` open-addressing hash map |
| `vec` | `vec2/3/4<T>` (`float3`, `int4`, ...) |
| `math` | libm at both float widths, `mul_add` (FMA) |
| `os` | Files, directories, stdin/stdout, args, env, time, sleep, `resource_dir` |
| `exception` | Typed exceptions on top of `return … from` |
| `ffi` | `cstr`, `bytes` from raw C pointers |
| `binary`, `base64`, `csv`, `json`, `regex` | Binary readers, RFC 4648, RFC 4180, RFC 8259, a Rust-`regex`-style engine |
| `gfx`, `audio`, `ui`, `physics` | External packages [goose_gfx](https://github.com/aardappel/goose_gfx) (SDL3 GPU, audio, Nuklear UI) and [goose_physics](https://github.com/aardappel/goose_physics) (Box3D) |

---

## 4. What is being worked on / open items

The project tracks open work in **`docs/goose_spec.md` Appendix B (TODO / open
items)**, not in code comments. `src/` has only two real TODO markers.

### Spec Appendix B (open)

| Item | Topic |
|---|---|
| 0a | Mixed-signedness ergonomics: BCE loses a `u64`'s range once it is bound to a local (`bench/goose/words.goose` keeps 4 checks because of this) |
| 0f | BCE gaps: disjunctive loop exits, indices loaded from arrays |
| 0c | Writing through optionals without narrowing them first |
| 0d | Lifetime precision: long-distance returns carry only global or static references; the recursive-cycle store rule is conservative (TODO at `src/typecheck.h:52`) |
| 2 | Error-propagation sugar (a `try`-like layer) |
| 3 | Moves for resizable values |
| 5 | Refining the cycle store rule (per-activation reasoning) |
| 6 | "Current pool" implicit destinations |
| 7 | Mixed-type pools, pool GC and compaction |
| 8 | Multiple resizables per struct, two-way growth arrays |
| 9 | Concurrency: queue fairness, `select`, sending relative-ref trees through queues |
| 10 | SIMD alignment and aligned types |
| 13 | Labeled `break` |
| 15 | A WebAssembly target (`docs/design/wasm.md`) |
| 16 | Relative-reference region tracking, which would allow copying self-linked values (TODO at `src/typecheck_types.h:828`) |

### Design docs that describe future work

| Doc | Status |
|---|---|
| `docs/design/root_structs.md` | Accepted direction; implementation planned |
| `docs/design/scope_exit_cleanup.md` | Research note: `defer` is now implemented; destructor types, pool finalizers and `errdefer` are not |
| `docs/design/nested_growth.md` | Research note: building a recursive tree (e.g. a JSON tape) in place |
| `docs/design/coroutines.md` | Design note: stackless, value-typed coroutines scheduled by libraries |
| `docs/design/soa.md` | Proposal: column (struct-of-arrays) arrays `T[||..]` |
| `docs/design/wasm.md` | Proposal: a wasm target |
| `docs/design/owning_dynamic_data.md` | Research: independent dynamic stacks, opaque resources |
| `docs/design/const_for.md` §10 | Future work: `const if`, constant ranges, more fragment positions |
| `docs/design/language_server.md` §10 | LSP gaps: UTF-8 position encoding, better exemplars, memory use with many roots |
| `docs/design/jit_backend.md` | TLS under TinyCC (so threaded programs can run in the JIT), backtraces on ELF and Mach-O |
| `bench/notes.md` | Compiler work ordered by measured benefit (root classes, specializing `push_n`, base-case inlining) |

### Deliberately out of scope (for now)

Moves for resizable values, more than one resizable per struct, labeled
`break`, namespace privacy and re-exports, subprocesses and networking in the
stdlib, alignment annotations, pool GC.

### Recent development themes (git log)

- CLI polish: `goose format`, `completion`, `help --man`, quiet-by-default output with `--stats`, `docs/command_line.md`, colored errors, version from git describe, "did you mean" for mistyped commands.
- Removing dead code and sharing helpers across the typechecker, optimizer, codegen and LSP.
- More precise relative references and result construction.
- Runtime robustness on Windows, plus Android support in subprocess.h.
- Small stdlib additions such as `math.mul_add`, `math.is_finite` and f32 forms, correctly rounded `parse_flt`, unbiased `rand_int`.
- The `defer` statement.
- Rewriting the documentation prose.

---

## 5. Where you can contribute

The ideas are grouped from easiest to hardest. There is no CONTRIBUTING file,
so the conventions are listed at the end of this section. Ask on Discord
before you start a large language change.

### Easy: documentation fixes and housekeeping

1. **`docs/design/dynamic_externs.md:30`** still says "Not implemented". The feature landed in PR #59 and is tested by `test/extern_dylib.py`. Update the status line here and in `docs/index.md`.
2. **`README.md:567`** says "fourteen modules", while `docs/index.md` and `docs/stdlib.md` say sixteen. Make them agree.
3. **`vscode/README.md:169`** says the compiler "stops at the first error". That is no longer true now that the parser recovers from errors.
4. **Add a `CONTRIBUTING.md`** and a PR template: how to build, how to run tests, fixture conventions (from `docs/testing.md`), the `goose format --check` rule, and when to regenerate the runtime header.
5. **Add the tree-sitter check to CI.** `python tree-sitter/build.py --check` currently runs only by hand.

### Medium: editor and tooling work

6. **Tree-sitter queries.** Only `highlights.scm` exists. Add `locals.scm`, `indents.scm`, `folds.scm`, `textobjects.scm` and `injections.scm` (`tree-sitter/queries/`). Upstreaming to nvim-treesitter or Helix, or a Zed extension, would also help.
7. **LSP features** in `src/lsp_features.h`: code actions or quick fixes (e.g. "insert `copy(x)`", "remove redundant `as`"), document highlight, go to implementation for case functions, range formatting, UTF-8 position encoding.
8. **Formatter** (`src/format.h`): range formatting, ignore regions.
9. **Run `test/lsp_sweep.py --quick` in CI**, and add fuzzing of format idempotence.

### Medium: standard library

10. **A `process` module** over the already vendored `third_party/subprocess`, and a sockets or networking module (both explicitly missing from v1).
11. **More of `os`**: file metadata (size, mtime), path helpers, date and time formatting.
12. **Utilities**: hashing (crc32, sha256), hex encoding, an INI or TOML reader, UTF-8 validation.
13. **Faster library loops**: specialize `push_n` and similar element loops (`bench/notes.md`).

### Hard: compiler work (pick an Appendix B item)

14. **BCE** (`src/bce.h`): carry a `let`'s initializer range (item 0a); handle disjunctive loop exits (item 0f).
15. **Region tracking for self-relative links** (item 16, `src/typecheck_types.h:828`).
16. **Lifting C-backend rejections** listed in `docs/implementation.md` §10, such as `==` on resizable structs and `str` into fixed destinations.
17. **The optimizer** (`optimize_basecase.h`, `optimize_tre.h`): base-case inlining when the base case is not the first statement; expression-bodied folds in tail-recursion elimination.
18. **JIT** (`src/jit.h`, `src/runtime/runtime_threads.h`): emulate TLS under TinyCC so threaded programs can run in-process.
19. **Serialization** (`docs/design/serialization.md` §7): references into payload fields, big-endian hosts.
20. **Larger features with design docs** (talk to the maintainer first): labeled `break`, moves for resizables, `root_structs`, SoA arrays, a wasm target, coroutines.

### Contribution conventions (inferred from CI and history)

- CI must pass on Linux, macOS and Windows, plus the ASan/UBSan job.
- `build/goose format --check samples stdlib` must pass.
- New test fixtures need an expected output in `test/expected/<name>.out`, and fixture names must be unique across categories. Rejection fixtures use `// error: substring` lines.
- If you change the grammar, update `tree-sitter/grammar.js` in the same change.
- If you edit `src/runtime/*`, run `build/goose --gen-runtime-header` and rebuild.
- Commit subjects are imperative, plain English, with the PR number in parentheses, e.g. `Add goose completion, completion scripts made from the help (#95)`.

---

## 6. Setup guide

### 6.0 How to get each component

These aren't separate downloads. The compiler, standard library, language
server and formatter all come together; only the editor support needs its own
install step.

#### Compiler, standard library, language server and formatter

**Option A: prebuilt release (macOS example)**

1. Go to <https://github.com/aardappel/goose/releases> and download the macOS archive (arm64 for Apple Silicon, x64 for Intel).
2. Unpack it, for example to `~/tools/goose`, then:

   ```bash
   xattr -dr com.apple.quarantine ~/tools/goose   # otherwise macOS blocks the files from running
   echo 'export PATH="$HOME/tools/goose:$PATH"' >> ~/.zshrc && source ~/.zshrc
   xcode-select --install                          # SDK headers, needed to run programs
   ```

   The archive also includes the standard library, docs, samples and the VS Code extension.

**Option B: a local clone.** After building (§6.2), put `build/` on your PATH:

```bash
echo 'export PATH="/path/to/goose/build:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

To update it later: `git pull && cmake --build build -j 8`.

Either way, you then have:

| Component | How you use it |
|---|---|
| Compiler | `goose file.goose`, `goose build file.goose` |
| Standard library | Found automatically: in the repo it uses `stdlib/`, in a release the copy beside the binary. Just write `import std;` |
| Language server | `goose lsp` (editors start it for you) |
| Formatter | `goose format file.goose` |

Check it works: `goose version`

#### VS Code extension

The extension is checked into the repo (and included in releases), so there's nothing to download:

```bash
code --install-extension /path/to/goose/vscode/goose-language.vsix
```

If `code` isn't found, open VS Code, press Cmd+Shift+P and run "Shell Command:
Install 'code' command in PATH". You can also go to Extensions → `...` →
"Install from VSIX…" and pick the file.

The extension gives syntax highlighting, errors as you type, hover, go to
definition and one-key runs. If VS Code can't find the compiler, set
`goose.compilerPath` in its settings to your `goose` binary.

#### Tree-sitter grammar (only for Neovim, Helix or Zed)

VS Code users can skip this. Otherwise:

```bash
cd /path/to/goose
python3 tree-sitter/build.py      # generates the parser (needs Node/npm)
```

Then follow `tree-sitter/README.md` for your editor. `docs/editors.md` covers
connecting `goose lsp` to Neovim, Helix and Emacs.

#### CI

There's nothing to download for CI. It runs on GitHub on every push and pull
request (`.github/workflows/ci.yml`, see §6.8). To run the same tests on your
machine:

```bash
python3 test/run_tests.py --exe build/goose
```

### 6.1 Option A: use a prebuilt release

1. Download an archive for your platform from <https://github.com/aardappel/goose/releases>.
2. Unpack it anywhere and add the directory to `PATH`.
3. On macOS, clear the quarantine flag: `xattr -dr com.apple.quarantine <dir>`.
4. Runtime requirements:
   - **macOS**: Xcode command line tools (`xcode-select --install`). The macOS compiler needs macOS 13.3 or later.
   - **Linux**: libc headers (`libc6-dev` / `glibc-devel`) and glibc 2.35 or later.
   - **Windows**: nothing extra for `goose file.goose`.
   - `goose build` also needs a C compiler: VS 2022+ or clang on Windows, gcc or clang elsewhere.

### 6.2 Option B: build from source

**Prerequisites**

- CMake 3.27 or later
- A C++20 compiler (clang, gcc or MSVC)
- Python 3, for the test and sample runners
- git
- macOS: Xcode command line tools. TinyCC needs the SDK headers.
- Linux with graphics: the SDL X11/Wayland development packages (the list is in `.github/workflows/ci.yml` and `third_party/SDL/docs/README-linux.md`)

**Build**

```bash
git clone https://github.com/aardappel/goose
cd goose

# Release build, with gfx/audio/ui/physics packages compiled in (fetched with git):
cmake -B build -DCMAKE_BUILD_TYPE=Release -DGOOSE_BUILTIN_LIBS=all
cmake --build build --config Release -j 8

# Compiler binary: build/goose   (Visual Studio generator: build/Release/goose.exe)
build/goose version
```

**CMake options**

| Option | Values | Effect |
|---|---|---|
| `CMAKE_BUILD_TYPE` | `Release`, `Debug`, `RelWithDebInfo` | Debug turns on compiler assertions (CI uses Debug) |
| `GOOSE_BUILTIN_LIBS` | `""` (default), `all`, `gfx`, `physics` | Compiles the external packages into the compiler. Without it, a package is built into `~/.goose` the first time a program imports it (needs git, cmake and a C compiler) |
| `GOOSE_VERSION` | string | Overrides `git describe` |
| `GOOSE_TCC_LIB_PATH`, `GOOSE_TCC_SYSINCLUDEPATHS`, `GOOSE_TCC_LIBPATHS` | paths | For packagers (Nix, etc.) |

There is no `option()` for sanitizers. Pass the flags through `CMAKE_CXX_FLAGS`
the way CI does:

```bash
cmake -B build-sanitize -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_CXX_FLAGS="-O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer -fno-sanitize-recover=all"
cmake --build build-sanitize -j 8
```

### 6.3 Running programs

```bash
build/goose samples/01_tour.goose              # JIT, in-process (same as `goose run`)
build/goose check samples/01_tour.goose        # typecheck only
build/goose build samples/01_tour.goose && samples/01_tour   # native executable
build/goose build file.goose -o out/app        # choose the output path
build/goose file.goose -- arg1 arg2            # pass program arguments
```

Programs that use **threads must be built with `goose build`**, because
TinyCC cannot place thread-local storage.

| Flag | Meaning |
|---|---|
| `-O0` / `-O1` / `-O2` | Inlining level (default `-O2`) |
| `--debug` | Overflow, range and tag checks that name the source line, plus C debug info |
| `--stats` | Print the compile summary (`parsed ok`, `typechecked ok`, `bce`, `wrote`); a successful run prints only the program's output by default |
| `--cc msvc\|clang\|gcc\|cc\|path` | Choose the C compiler (`goose toolchain` shows which one is found) |
| `--dry-run`, `-v` | Show the build commands without running them / as they run |
| `--bce-lines` | Report the bounds checks that remain on each line |
| `--stacks` | Report how many data stacks the program uses |
| `--stack-reserve 16G` | Address space reserved per data stack (default 2G) |
| `--diagnostics json` | Machine-readable errors |
| `-D NAME=VALUE` | C define (e.g. `-DGS_STACK_STATS=1`) |
| `--standalone`, `--header h` | Emit self-contained C, or a header for C hosts |

Emitting the C yourself:

```bash
build/goose -o tour.c samples/01_tour.goose
build/goose --emit-runtime goose_runtime.c
cc -O2 -c goose_runtime.c -o goose_runtime.o
cc -O2 tour.c goose_runtime.o -o tour -lm -pthread
```

Other commands:

```bash
build/goose format file.goose        # rewrite in place
build/goose format --check samples stdlib
build/goose toolchain                # show the C compiler, cmake, git, GOOSE_HOME
build/goose fetch file.goose         # fetch git packages
build/goose completion zsh           # shell completion script
build/goose help --man               # the full help as a man page
```

Environment variables: `GOOSE_HOME` (default `~/.goose`), `GOOSE_CC`,
`GOOSE_STDLIB`, `GOOSE_PROGRESS=plain|live`.

### 6.4 Programs with their own C, and packages

A sidecar file `foo.build` beside `foo.goose`:

```
c_sources = ["impl.c"];
c_include = ["include"];
c_defines = ["FOO=1"];
c_libs_linux = ["m"];
dylibs_linux = ["SDL2=libSDL2-2.0.so.0"];
```

A program uses a library through its root file:

```goose
import mylib from "./lib";              // a local directory
import other from "owner/repo@v1";      // a GitHub repo at a tag or commit
import more from "host/owner/repo@ref"; // any git host
```

See `docs/packages.md` for details.

### 6.5 Tests

```bash
python test/run_tests.py                       # the whole suite (uses build/Release, then build, ...)
python test/run_tests.py --exe build/goose -j 8
python test/run_tests.py --profile baseline --cc native --require-clang   # what CI runs
python test/run_tests.py --no-jit              # skip TinyCC runs
python test/run_tests.py --nocgen              # skip everything that needs a C compiler
python samples/run_samples.py                  # every sample, JIT + native
python samples/run_samples.py --bless          # rewrite the expected outputs
python scripts/check_doc_examples.py docs/reference.md --run -v   # compile and run the doc examples
python bench/run_bench.py --only tree --sizes small --reps 1       # benchmarks
```

How the fixtures are organized (`test/`):

- **Feature categories**: `syntax/`, `typing/`, `lifetimes/`, `codegen/`, `optimizer/`, `runtime/`, `storage/`, `threads/`, `stdlib/`, plus `gfx/`, `ui/`, `audio/`, `physics/`.
- **Rejection tests**: `errors/` (parse and resolve) and `errors_tc/` (semantic), using `// error: substring` lines.
- **Expected outputs**: `expected/<name>.out` (with `.aborts` and `.stderr` files for expected aborts).
- **Bounds checks**: `// bce:elide` and `// bce:keep` annotations, verified with `--bce-test`.

`docs/testing.md` has the full description.

### 6.6 Editor support

```bash
code --install-extension vscode/goose-language.vsix   # VS Code: highlighting, LSP, one-key run
python vscode/build_vsix.py                           # rebuild the extension (Node 22+)
cd vscode && npm ci && npm test                       # extension tests
python tree-sitter/build.py && python tree-sitter/build.py --check   # tree-sitter grammar
```

VS Code settings: `goose.compilerPath`, `goose.entryFile`, `goose.stdlibPath`,
`goose.useLanguageServer`. For Neovim, Helix and Emacs, point the editor at
`goose lsp` (see `docs/editors.md` and `tree-sitter/README.md`).

### 6.7 Docs site

```bash
python docs/site/build.py --out build/site --check   # needs pandoc >= 2.11
```

### 6.8 CI at a glance (`.github/workflows`)

| Workflow | What it does |
|---|---|
| `ci.yml` (`test`) | Ubuntu, macOS and Windows; Debug build with `GOOSE_BUILTIN_LIBS=all`; `format --check` (Linux); `run_tests.py`; VS Code extension tests |
| `ci.yml` (`sanitize`) | Ubuntu with clang, ASan + UBSan build, `run_tests.py --profile sanitize` |
| `pages.yml` | Builds and deploys the docs site on pushes to `master` |
| `release.yml` | On `v*` tags: Release builds for 4 targets, packaging, sample runs, publishing |

---

## 7. Suggested reading order

1. `README.md`: the pitch and the features.
2. [syntax.md](syntax.md): every piece of syntax on one page.
3. `samples/01_tour.goose` … `samples/31_mini_doom.goose`, in order (`samples/README.md` describes each).
4. `docs/tutorial.md`, then `docs/reference.md` (it covers everything) and `docs/goose_spec.md` (the exact rules).
5. `docs/implementation.md`, before you touch the compiler.
6. `docs/goose_spec.md` Appendix B, to pick something to work on.
