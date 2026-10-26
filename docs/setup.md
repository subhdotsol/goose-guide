# Goose: Setup, Build, Test and Update Guide (macOS)

This guide records how this repo is set up on this machine and gives the
exact commands to build, test and update every part of it.

- Repo path: `/Users/subh/Desktop/code-playground/oss/goose`
- `origin` remote: `https://github.com/subhdotsol/goose.git` (your fork)
- Original project: `https://github.com/aardappel/goose.git` (called `upstream` below)

Every command assumes you are in the repo root:

```bash
cd /Users/subh/Desktop/code-playground/oss/goose
```

---

## 1. What this machine has

These are the versions found on this machine. Any version at or above the minimum works.

| Tool | Version here | Needed for | Minimum |
|---|---|---|---|
| CMake | 4.4.4 (Homebrew) | building the compiler | 3.27 |
| C/C++ compiler | Apple clang 21 (`/usr/bin/cc`, `/usr/bin/clang++`) | building the compiler and `goose build` | C++20 |
| Xcode command line tools | installed | the SDK headers TinyCC needs | – |
| Python | 3.14 | test and sample runners | 3.x |
| git | 2.55 (Homebrew) | packages, version string | – |
| Node / npm | 24 (nvm) | VS Code extension, tree-sitter | Node 22+ |
| VS Code `code` CLI | `/usr/local/bin/code` | installing the extension | – |

If any of these are missing on a new Mac:

```bash
xcode-select --install          # clang + SDK headers
brew install cmake git python   # Homebrew packages
# Node: install nvm, then:  nvm install 22
```

Check what Goose itself detects:

```bash
build/goose toolchain
```

---

## 2. How the repo was set up (what was actually done)

1. **Cloned your fork:**
   ```bash
   git clone https://github.com/subhdotsol/goose.git
   cd goose
   ```
2. **Configured a Release build** with the default generator (Unix Makefiles)
   and **no** builtin graphics or physics packages:
   ```bash
   cmake -B build -DCMAKE_BUILD_TYPE=Release
   ```
   The current configuration is recorded in `build/CMakeCache.txt`
   (`CMAKE_BUILD_TYPE=Release`, `GOOSE_BUILTIN_LIBS=` empty).
3. **Built the compiler:**
   ```bash
   cmake --build build -j 8
   ```
   This produces `build/goose`. The binary had fallen behind the source after
   new commits, so it was rebuilt with the same command. `build/goose version`
   should print the current commit hash (e.g. `goose a108677d ...`).
4. **Put `goose` on the PATH** (see §3).

---

## 3. Make the `goose` command available everywhere

```bash
echo 'export PATH="/Users/subh/Desktop/code-playground/oss/goose/build:$PATH"' >> ~/.zshrc
source ~/.zshrc

which goose        # /Users/subh/Desktop/code-playground/oss/goose/build/goose
goose version
```

Since the PATH points straight into `build/`, every rebuild updates the
`goose` command automatically. There is nothing to reinstall.

---

## 4. Building each part

### 4.1 Compiler (includes the language server, formatter and stdlib lookup)

```bash
# First time (or after deleting build/):
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j 8

# Every time after that:
cmake --build build -j 8
```

The compiler finds the standard library in `stdlib/` of this source tree
automatically. The language server is `goose lsp` and the formatter is
`goose format`, both inside the same binary.

### 4.2 Compiler with graphics, audio, ui and physics built in (optional)

This is needed only for the gfx and physics samples (`27_gfx_cube` … `31_mini_doom`).
It fetches the `goose_gfx` and `goose_physics` packages with git at configure time.

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release -DGOOSE_BUILTIN_LIBS=all
cmake --build build -j 8
goose toolchain        # "built in:" should now list gfx, audio, ui, physics
```

Without this, a program that imports one of those packages builds it into
`~/.goose` the first time it is used, which needs git, cmake and a C compiler.

### 4.3 Debug compiler (compiler assertions on, like CI)

Use a separate folder so it doesn't replace your Release build:

```bash
cmake -B build-debug -DCMAKE_BUILD_TYPE=Debug -DGOOSE_BUILTIN_LIBS=all
cmake --build build-debug -j 8
build-debug/goose version
```

### 4.4 Sanitizer compiler (ASan + UBSan, like the CI `sanitize` job)

```bash
cmake -B build-sanitize -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_CXX_FLAGS="-O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer -fno-sanitize-recover=all"
cmake --build build-sanitize -j 8
```

### 4.5 The embedded C runtime (only if you edit `src/runtime/*`)

`src/runtime_inline.h` is generated from `src/runtime/`. After editing the runtime:

```bash
build/goose --gen-runtime-header
cmake --build build -j 8
```

### 4.6 VS Code extension

To install the prebuilt one that is in the repo:

```bash
code --install-extension vscode/goose-language.vsix
```

To rebuild it from source (Node 22+; this also runs its tests):

```bash
python3 vscode/build_vsix.py
code --install-extension vscode/goose-language.vsix --force
```

For development, open the `vscode/` folder in VS Code and press **F5** to launch
an Extension Development Host. If VS Code can't find the compiler, set
`goose.compilerPath` to
`/Users/subh/Desktop/code-playground/oss/goose/build/goose`.

### 4.7 Tree-sitter grammar (for Neovim, Helix or Zed)

```bash
python3 tree-sitter/build.py            # generate the parser (installs a pinned tree-sitter-cli)
python3 tree-sitter/build.py --check    # run the corpus and parse every .goose file in the repo
```

Editor setup is in `tree-sitter/README.md` and `docs/editors.md`.

### 4.8 Documentation site

```bash
brew install pandoc
python3 docs/site/build.py --out build/site --check
open build/site/index.html
```

---

## 5. Running Goose programs

```bash
goose samples/01_tour.goose                 # compile and run in-process (JIT)
goose check samples/01_tour.goose           # typecheck only
goose build samples/01_tour.goose           # native executable beside the source
./samples/01_tour
goose build samples/01_tour.goose -o /tmp/tour && /tmp/tour
goose build --debug file.goose              # runtime overflow and range checks + debug info
goose file.goose -- arg1 arg2               # pass arguments to the program
goose -q file.goose                         # print only the program's output
goose format file.goose                     # format in place
goose format --check samples stdlib         # what CI checks
```

Programs that use threads must use `goose build`. The in-process JIT
can't run them.

---

## 6. Testing

### 6.1 Main test suite

```bash
python3 test/run_tests.py --exe build/goose -j 8
```

This parses, typechecks, round-trips, compiles at `-O0` and `-O2`, runs the
JIT, and compares against `test/expected/*.out`. It also runs the samples,
the doc-example check, the formatter, LSP, CLI checks and the Goose-in-Goose
bootstrap.

Useful variants:

```bash
python3 test/run_tests.py --exe build/goose --no-jit     # skip the TinyCC runs
python3 test/run_tests.py --exe build/goose --nocgen     # skip everything that needs a C compiler (fast)
python3 test/run_tests.py --exe build/goose -v           # verbose
python3 test/run_tests.py --profile baseline --cc native --require-clang --exe build-debug/goose   # same as CI
python3 test/run_tests.py --exe build-sanitize/goose --profile sanitize --cc clang                  # sanitizer run
```

Without `--exe`, the runner picks the first of `build/Release`,
`build/RelWithDebInfo`, `build` and `build/Debug`.

### 6.2 Samples only

```bash
python3 samples/run_samples.py --exe build/goose
python3 samples/run_samples.py --exe build/goose --bless   # rewrite the expected outputs (only when a change is intended)
```

Graphics and physics samples are skipped unless the compiler was built with
`-DGOOSE_BUILTIN_LIBS=all` (§4.2).

### 6.3 Documentation examples

```bash
python3 scripts/check_doc_examples.py docs/reference.md --run -v --exe build/goose
```

### 6.4 VS Code extension tests

```bash
cd vscode
npm ci
GOOSE_TEST_COMPILER=/Users/subh/Desktop/code-playground/oss/goose/build/goose npm test
cd ..
```

### 6.5 Tree-sitter, LSP and format checks

```bash
python3 tree-sitter/build.py --check
python3 test/lsp_sweep.py --quick
build/goose format --check samples stdlib
```

### 6.6 Benchmarks (optional, slow)

```bash
python3 bench/run_bench.py --only tree --sizes small --reps 1
```

---

## 7. Updating when new code is pushed

### 7.1 One-time: add the original project as `upstream`

`origin` is your fork. New code lands in the original repo first, so add it as a second remote:

```bash
git remote add upstream https://github.com/aardappel/goose.git
git remote -v        # should list both origin and upstream
```

### 7.2 Every update

```bash
cd /Users/subh/Desktop/code-playground/oss/goose

# 1. Make sure you have no uncommitted work (commit or stash it first)
git status
git stash            # only if you have local changes you want to keep aside

# 2. Get the new code
git checkout master
git fetch upstream
git merge --ff-only upstream/master     # or: git pull upstream master

# 3. Keep your fork on GitHub in sync (optional)
git push origin master

# 4. Rebuild the compiler (CMake picks up changed files and CMakeLists.txt itself)
cmake --build build -j 8

# 5. Confirm the version matches the new commit
goose version
git log --oneline -1

# 6. Run the tests (the --nocgen pass is quick; the full run is thorough)
python3 test/run_tests.py --exe build/goose --nocgen
python3 test/run_tests.py --exe build/goose -j 8

# 7. Restore your stashed work, if you stashed in step 1
git stash pop
```

If `git merge --ff-only` refuses, you have local commits on `master`. Use
`git rebase upstream/master` (or `git merge upstream/master`) instead. Better
still, keep your own work on separate branches (§8).

### 7.3 Also update the other parts when they change

| If the update touched... | Run |
|---|---|
| `src/runtime/*` (and `runtime_inline.h` was not updated by the commit) | `build/goose --gen-runtime-header && cmake --build build -j 8` |
| `vscode/` | `code --install-extension vscode/goose-language.vsix --force` |
| `tree-sitter/` | `python3 tree-sitter/build.py` |
| `src/blessed.txt` (package versions), with a `GOOSE_BUILTIN_LIBS=all` build | `cmake -B build -DGOOSE_BUILTIN_LIBS=all && cmake --build build -j 8` |

To see what an update changed:

```bash
git diff --stat HEAD@{1} HEAD
```

### 7.4 When the build breaks after an update: a clean rebuild

```bash
rm -rf build
cmake -B build -DCMAKE_BUILD_TYPE=Release        # add -DGOOSE_BUILTIN_LIBS=all if you use it
cmake --build build -j 8
```

If compiled programs or packages behave strangely after an update, clear
Goose's own cache too. It is rebuilt on demand:

```bash
rm -rf ~/.goose
```

---

## 8. Working on your own changes (contribution workflow)

```bash
git checkout master && git fetch upstream && git merge --ff-only upstream/master
git checkout -b my-fix                  # a branch for your work

# ... edit ...
cmake --build build -j 8
build/goose format --check samples stdlib
python3 test/run_tests.py --exe build/goose -j 8

git add -A && git commit -m "Fix stale status line in dynamic_externs.md"
git push -u origin my-fix               # then open a PR to aardappel/goose on GitHub
```

Conventions for a pull request:

- Commit subjects are imperative and in plain English.
- CI must pass on Linux, macOS and Windows.
- New test fixtures need a `test/expected/<name>.out` file.
- If you change the grammar, update `tree-sitter/grammar.js` too.

---

## 9. Quick troubleshooting

| Problem | Fix |
|---|---|
| `goose: command not found` | redo §3, then `source ~/.zshrc` |
| `goose version` shows an old commit | `cmake --build build -j 8` |
| TinyCC errors about missing headers | `xcode-select --install` |
| A threaded program fails under `goose file.goose` | use `goose build file.goose` |
| gfx or physics samples are skipped | rebuild with `-DGOOSE_BUILTIN_LIBS=all` (§4.2) |
| The VS Code extension can't find the compiler | set `goose.compilerPath` to `.../goose/build/goose` |
| Strange build errors after `git pull` | clean rebuild (§7.4) |
