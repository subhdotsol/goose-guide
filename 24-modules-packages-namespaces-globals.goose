// =====================================================================
// 24. Modules, packages, namespaces, globals
// ---------------------------------------------------------------------
// Run from the goose-guide directory (paths below are relative to THIS file):
//     ../oss/goose/build/goose 24-modules-packages-namespaces-globals.goose
// With program arguments (everything after `--` goes to the program):
//     ../oss/goose/build/goose 24-modules-packages-namespaces-globals.goose -- hello world
//
// Supporting files live in 24-modules/:
//   24-modules/geolib/geolib.goose        package entry (namespace geolib)
//   24-modules/geolib/extra.goose         a second package module
//   24-modules/geolib/helpers.goose       imported with `import .helpers;`
//   24-modules/geolib/util/strings.goose  imported with `import util.strings;`
//   24-modules/table.bin                  bytes read by embed_file
// =====================================================================

// ---------------------------------------------------------------------
// Imports
// ---------------------------------------------------------------------
// An import INCLUDES a file exactly once and creates NO namespace by itself:
// you get whatever the file declares, under whatever namespace it declares.
import std;                // a standard-library module, imported by name
import dictionary;         // another stdlib module (hash map: dictionary<K, V>)
import os;                 // stdlib `os`: args(), arg(i), arg_count() live here (global namespace)

// `import name from "source";` declares a PACKAGE named `name` and imports its
// entry module `name.goose` from that directory. A path is relative to the
// file containing the import, and nothing is copied (edit the lib, rerun).
// ONLY the root file (the one given on the command line) may declare
// packages; the same line in any other file is just a *requirement* that the
// root must satisfy — so dependencies are flat, pinned and in one place.
import geolib from "./24-modules/geolib";

// Other modules of a declared package are imported by package name:
import geolib.extra;       // -> 24-modules/geolib/extra.goose

// Path-style imports, demonstrated INSIDE the package (see geolib.goose):
//   import util.strings;   // util/strings.goose, relative to the package root
//   import .helpers;       // helpers.goose, relative to the importing file
// (From this root file, `import util.strings;` would look for
//  goose-guide/util/strings.goose, since a program's own package root is the
//  directory of its root file.)

// A package from GitHub at a tag or commit. Not run here because it needs
// network access and a real repository; the compiler would fetch it once
// into ~/.goose/pkg (`goose fetch file.goose` prefetches):
//   import other from "owner/repo@v1";
//   import other from "github.com/owner/repo@3f2c1a9";

// ---------------------------------------------------------------------
// Globals
// ---------------------------------------------------------------------
// Globals are initialized BEFORE main: imported files first, then this file
// in declaration order. Naming a global before its initializer has run is an
// error.
var log: u8[>..];                     // a var with only a type starts empty (or default)
var hits: i64;                        // scalar with only a type -> default value 0
let NAMES = ["ada", "grace"];         // untyped const global = named constant / static data
let SIZE = 4;                         // a named constant...
var grid: u8[SIZE] = [0; SIZE];       // ...usable as an array size
let LAST = NAMES.len - 1;             // constant expressions over constants also work
var counts: i64[NAMES.len] = [0; NAMES.len];
let data = embed_file("24-modules/table.bin");  // file bytes read at COMPILE time -> const u8[:]
                                                // (path relative to this source file)
var started = make_banner();          // an initializer may call functions

fn make_banner() -> u8[>..] { str("init ran before main; NAMES.len=", NAMES.len) }

// A GLOBAL-namespace `describe`. geolib declares its own `geolib::describe`
// which shadows this one inside geolib; geolib reaches this one as ::describe.
fn describe(n: i64) -> u8[>..] { str("global describe(", n, ")") }

fn main() {
    // -----------------------------------------------------------------
    // Namespaces: qualified names
    // -----------------------------------------------------------------
    // geolib.goose starts with `namespace geolib;`, so its declarations are
    // written geolib::Name from outside.
    let p = geolib::Pt { -3, 4 };                  // struct literal of a namespaced type
    print("p = ", p);                              // print finds geolib::format via p's type
    print("geolib::norm1(p) = ", geolib::norm1(p));

    // UFCS: p.norm1() searches the RECEIVER TYPE's namespace (geolib) first,
    // so it works without writing geolib:: — a plain `norm1(p)` would NOT.
    print("p.norm1() = ", p.norm1());
    // norm1(p);   // error: no `norm1` in the global namespace

    // Declarations from other modules of the same namespace:
    print("geolib::origin() = ", geolib::origin());      // from extra.goose
    print("geolib::label(p) = ", geolib::label(p));      // uses util/strings + helpers

    // `::name` names the GLOBAL declaration that a namespaced one shadows.
    print("describe(7)   = ", describe(7));              // here (global ns) -> global one
    print("geolib::describe(7) = ", geolib::describe(7));
    print("inside geolib: ", geolib::shadow_demo());     // geolib uses describe and ::describe
    print("::describe(8) = ", ::describe(8));            // explicit global from anywhere

    // `fn ::name` inside a namespaced file declares into the GLOBAL namespace:
    print("geolib_banner() = ", geolib_banner());

    // Rules: no privacy (everything in geolib is visible), no re-export, and
    // no nesting of namespaces (`namespace a::b;` does not exist).

    // -----------------------------------------------------------------
    // Using globals
    // -----------------------------------------------------------------
    print("started = ", started);
    log.append("started");                         // the empty global builder grows
    hits += 1;
    counts[LAST] += 1;                             // LAST = 1
    grid[SIZE - 1] = 9;
    print("log = ", log, ", hits = ", hits);
    print("NAMES[LAST] = ", NAMES[LAST], ", counts = ", counts);
    // (a u8 array prints as TEXT, so print the elements as numbers instead)
    print("grid len = ", grid.len, ", grid[0] = ", grid[0], ", grid[3] = ", grid[SIZE - 1]);
    print("embedded data len = ", data.len, ", bytes = ", data[0], " ", data[1], " ", data[2],
          ", as text = ", data);

    // -----------------------------------------------------------------
    // The dictionary module we imported
    // -----------------------------------------------------------------
    var ages: dictionary<i64, i64> = dictionary<i64, i64> {};
    ages.insert(36, 1815);                          // key, value
    print("dictionary contains 36: ", ages.contains(36), ", count = ", ages.count);

    // -----------------------------------------------------------------
    // Program arguments (from `os`, global namespace)
    // -----------------------------------------------------------------
    print("arg_count() = ", arg_count());          // includes argument 0 (the program)
    var a0: u8[>..] = [];
    arg(0, a0);                                    // arg(i, out) appends argument i to a builder
    print("arg(0) is ", a0.len, " bytes long");
    let all = args();                              // all of them as slices
    for i in 1..all.len { print("  arg ", i, " = ", all[i]); }
}
